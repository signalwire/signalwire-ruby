# frozen_string_literal: true

# RelayMockTest -- Ruby helper for the porting-sdk mock_relay WebSocket server.
#
# Mirrors the Python conftest fixtures (signalwire_relay_client + mock_relay)
# so unit tests can exercise the real Ruby SDK code path against a real
# WebSocket + HTTP control plane backed by switchblade-derived JSON schemas.
#
# The mock server's lifetime is per-test-process: the first call to
# RelayMockTest.client probes http://127.0.0.1:9779/__mock__/health and either
# confirms a running server or starts one as a subprocess via Process.spawn.
# Each test resets the journal/scenario state via RelayMockTest.reset.
#
# The default WebSocket port is 8779 and HTTP control-plane port is 9779
# (Ruby's slot in the relay parallel-rollouts plan).  Override with
# MOCK_RELAY_PORT / MOCK_RELAY_HTTP_PORT.

require 'net/http'
require 'json'
require 'uri'
require 'singleton'
require_relative '../../lib/signalwire/relay/client'
require_relative '../../lib/signalwire/relay/constants'

module RelayMockTest
  # `python -m mock_relay` cold-start can take a few seconds (module import
  # plus schema loading). Keep the budget slack but bounded.
  STARTUP_TIMEOUT_S = 30

  # JournalEntry mirrors the dict shape exposed at /__mock__/journal.
  # :method is the JSON-RPC method field name from the wire — keeping it (rather
  # than renaming to dodge the Struct#method override) preserves that mirroring.
  # rubocop:disable Lint/StructNewOverride
  JournalEntry = Struct.new(
    :timestamp, :direction, :method, :request_id, :frame,
    :connection_id, :session_id,
    keyword_init: true
  ) do
    # rubocop:enable Lint/StructNewOverride
    # Convenience: return the params hash from the JSON-RPC frame.
    def params
      (frame || {})['params'] || {}
    end

    # Convenience: return params['params'] (the inner event params).
    def event_params
      params['params'] || {}
    end

    # Convenience: return params['event_type'] for signalwire.event frames.
    def event_type
      params['event_type']
    end
  end

  # Private HTTP transport + journal-row marshalling for {Harness}. Extracted
  # into a module so Harness stays focused on the journal/scenario API.
  # Relies on the host's @http_url instance variable.
  module HarnessTransport
    private

    # "?session_id=<id>" suffix for control-plane calls when scoped, else "".
    # Reads the host Harness's @session_id (this module is included into it).
    def session_query
      @session_id ? "?session_id=#{URI.encode_www_form_component(@session_id)}" : ''
    end

    # Stamp this session id onto a timeline op's push/expect_recv spec when the
    # op doesn't already specify a session_id. Leaves sleep ops untouched.
    def scope_op(timeline_op)
      out = timeline_op.dup
      %w[push expect_recv].each do |key|
        spec = out[key]
        next unless spec.is_a?(Hash) && !spec.key?('session_id')

        out[key] = spec.merge('session_id' => @session_id)
      end
      out
    end

    def build_entry(row)
      JournalEntry.new(
        timestamp: row['timestamp'],
        direction: row['direction'],
        method: row['method'],
        request_id: row['request_id'],
        frame: row['frame'] || {},
        connection_id: row['connection_id'],
        session_id: row['session_id']
      )
    end

    def stringify_keys(obj)
      return obj unless obj.is_a?(Hash)

      obj.each_with_object({}) do |(k, v), out|
        out[k.to_s] = v.is_a?(Hash) ? stringify_keys(v) : v
      end
    end

    def http_get(path)
      with_retry do
        uri = URI("#{@http_url}#{path}")
        Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 10) do |http|
          require_success('GET', path, http.get(uri.request_uri))
        end
      end
    end

    def http_post(path, body = nil, read_timeout: 10)
      with_retry do
        uri = URI("#{@http_url}#{path}")
        Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: read_timeout) do |http|
          req = Net::HTTP::Post.new(uri.request_uri)
          req['Content-Type'] = 'application/json'
          req.body = body if body
          require_success('POST', path, http.request(req))
        end
      end
    end

    # Raise on a non-2xx HTTP response, else return its body (never nil).
    def require_success(verb, path, resp)
      raise "mocktest: #{verb} #{path} failed: #{resp.code} #{resp.body}" unless resp.is_a?(Net::HTTPSuccess)

      resp.body || ''
    end

    # Tolerate brief connection refusals while the mock is restarted by
    # +Lifecycle.respawn_if_dead+. Each retry waits 200ms and triggers a
    # fresh health probe + spawn through the singleton lifecycle.
    def with_retry
      attempts = 0
      begin
        yield
      rescue Errno::ECONNREFUSED
        attempts += 1
        raise if attempts > 10

        RelayMockTest::Lifecycle.instance.respawn_if_dead
        sleep 0.2
        retry
      end
    end
  end

  # Harness wraps the running mock-relay server. Exposes journal accessors,
  # scenario helpers, and a reset hook tests can call from setup / teardown.
  class Harness
    attr_reader :http_url, :ws_port, :http_port, :host

    # When set, journal reads, +reset+, scenario arming, pushes, inbound calls,
    # and +scenario_play+ ops are scoped to this session id (the server-assigned
    # +sessionid+ from the connect handshake), so a test only ever sees its own
    # frames and never disturbs another test's. +RelayMockTest.client+ sets this
    # automatically. +nil+ => global (legacy, single-threaded) view.
    attr_accessor :session_id

    def initialize(host:, ws_port:, http_port:)
      @host       = host
      @ws_port    = ws_port
      @http_port  = http_port
      @http_url   = "http://#{host}:#{http_port}"
      @session_id = nil
    end

    # Return a view of this harness scoped to +sid+. Shares the same HTTP
    # endpoint; only the session-scoping changes. Mirrors the TS
    # +newRelayClient+ per-call +MockRelayHarness+ whose +sessionId+ is set.
    def scoped(sid)
      view = Harness.new(host: @host, ws_port: @ws_port, http_port: @http_port)
      view.session_id = sid
      view
    end

    # WebSocket URL the SDK should connect to.
    def ws_url
      "ws://#{@host}:#{@ws_port}"
    end

    # Returns "host:port" suitable for SIGNALWIRE_RELAY_HOST.
    def relay_host
      "#{@host}:#{@ws_port}"
    end

    # ------------------------------------------------------------------
    # Journal
    # ------------------------------------------------------------------

    # Returns the most recent journal entry. Raises if empty.
    def last
      entries = journal
      raise 'mocktest: journal is empty - SDK call did not reach the mock server' if entries.empty?

      entries.last
    end

    # Returns every entry recorded since the last reset, in arrival order
    # (scoped to this harness's +session_id+ when set).
    def journal
      raw = http_get("/__mock__/journal#{session_query}")
      arr = JSON.parse(raw)
      arr.map { |e| build_entry(e) }
    end

    # Returns inbound (SDK -> server) journal entries, optionally filtered
    # by JSON-RPC method.
    def journal_recv(method: nil)
      entries = journal.select { |e| e.direction == 'recv' }
      entries = entries.select { |e| e.method == method } if method
      entries
    end

    # Returns server -> SDK frames, optionally filtered by inner event_type.
    def journal_send(event_type: nil)
      entries = journal.select { |e| e.direction == 'send' }
      return entries if event_type.nil?

      entries.select do |e|
        params = e.frame['params'] || {}
        e.frame['method'] == 'signalwire.event' &&
          params.is_a?(Hash) &&
          params['event_type'] == event_type
      end
    end

    # Clears journal + scenarios for this session (both scoped when
    # +session_id+ is set, global otherwise). Tests typically call this from
    # setup.
    def reset
      http_post("/__mock__/journal/reset#{session_query}")
      http_post("/__mock__/scenarios/reset#{session_query}")
    end

    # Reset this session's armed scenario queues (or all when unscoped).
    # Scenarios are session-scoped on the server, so a scoped harness clears
    # only its own queue -- safe under parallel execution.
    def reset_scenarios
      http_post("/__mock__/scenarios/reset#{session_query}")
    end

    # ------------------------------------------------------------------
    # Scenario plumbing
    # ------------------------------------------------------------------

    # Queue scripted post-RPC events for `method` (FIFO consume-once). Scoped
    # to this harness's session when set, so a parallel test's matching RPC
    # can't consume it.
    def arm_method(method, events)
      http_post(
        "/__mock__/scenarios/#{method}#{session_query}",
        JSON.generate(events.is_a?(Array) ? events : [events])
      )
    end

    # Queue a dial-dance scenario (winner state events + final dial event).
    # kwargs: tag, winner_call_id, states, node_id, device, losers, delay_ms.
    # Scoped to this harness's session when set.
    def arm_dial(**kwargs)
      http_post(
        "/__mock__/scenarios/dial#{session_query}",
        JSON.generate(stringify_keys(kwargs))
      )
    end

    # ------------------------------------------------------------------
    # Server-initiated pushes
    # ------------------------------------------------------------------

    # Push a single signalwire.event (or other) frame to the SDK. Targets this
    # harness's session by default (so a parallel test's client never receives
    # it); an explicit +session_id+ overrides, and an unscoped harness with no
    # arg broadcasts (legacy single-threaded behavior).
    def push(frame, session_id: nil)
      target = session_id || @session_id
      path = '/__mock__/push'
      path += "?session_id=#{URI.encode_www_form_component(target)}" if target
      resp = http_post(path, JSON.generate('frame' => frame))
      JSON.parse(resp)
    end

    # Inject an inbound call announcement. Targets this harness's session by
    # default so the inbound-call sequence is delivered only to this test's
    # client; an explicit +session_id+ overrides (unscoped harness broadcasts).
    def inbound_call(call_id: nil, from_number: '+15551234567',
                     to_number: '+15559876543', context: 'default',
                     auto_states: nil, delay_ms: 50, session_id: nil)
      body = {
        'from_number' => from_number, 'to_number' => to_number, 'context' => context,
        'auto_states' => auto_states || ['created'], 'delay_ms' => delay_ms
      }
      body['call_id'] = call_id unless call_id.nil?
      sid = session_id || @session_id
      body['session_id'] = sid unless sid.nil?
      JSON.parse(http_post('/__mock__/inbound_call', JSON.generate(body)))
    end

    # Run a scripted timeline of pushes/sleeps/expect_recv on the server.
    # When scoped, each +push+/+expect_recv+ op is stamped with this session id
    # (unless it already carries one), so the timeline targets only this test's
    # client and +expect_recv+ matches only this session's frames -- making it
    # parallel-safe.
    def scenario_play(ops)
      scoped = @session_id ? ops.map { |op| scope_op(op) } : ops
      resp = http_post('/__mock__/scenario_play', JSON.generate(scoped),
                       read_timeout: 30)
      JSON.parse(resp)
    end

    # List active WebSocket session metadata.
    def sessions
      raw = http_get('/__mock__/sessions')
      JSON.parse(raw)['sessions'] || []
    end

    include HarnessTransport
  end

  # Singleton lifecycle holder -- probe-or-spawn, then reuse.
  class Lifecycle
    include Singleton

    def initialize
      @mu      = Mutex.new
      @started = false
      @harness = nil
      @pid     = nil
    end

    def harness
      @mu.synchronize do
        return @harness if @started

        @started = true
        start_harness
      end
    end

    # Resolve ports, build the Harness, and probe-or-spawn the server.
    #
    # SIGNALWIRE_RELAY_SCHEME / SIGNALWIRE_RELAY_HOST are set HERE, exactly
    # once, inside the `@mu`-guarded one-time startup -- not per-client in
    # build_sdk_client. Those two are the SDK's only redirect channel (no
    # kwarg exists, client.rb:615/:625), so they must be process-global; what
    # must not be global is the WRITE. Setting them per-client meant every
    # `parallelize_me!` relay test re-wrote a process-global from its own
    # thread on every client build. Writing them once, before any parallel
    # suite starts, makes them read-only for the rest of the run.
    def start_harness
      @ws_port   = resolve_port('MOCK_RELAY_PORT')
      @http_port = resolve_port('MOCK_RELAY_HTTP_PORT')
      @host      = '127.0.0.1'
      @harness   = Harness.new(host: @host, ws_port: @ws_port, http_port: @http_port)
      ENV['SIGNALWIRE_RELAY_SCHEME'] = 'ws'
      ENV['SIGNALWIRE_RELAY_HOST']   = @harness.relay_host

      return @harness if probe_health(@harness)

      spawn_server(@host, @ws_port, @http_port)
      wait_for_health(@harness)
      @harness
    end

    # Idempotent: probe; if dead, spawn a fresh mock_relay and wait for
    # health. Called from the HTTP retry loop so a transient mock crash
    # mid-suite doesn't cascade into N test errors.
    def respawn_if_dead
      @mu.synchronize do
        return false if @harness && probe_health(@harness)

        spawn_server(@host || '127.0.0.1', @ws_port, @http_port)
        wait_for_health(@harness)
        true
      end
    end

    private

    def resolve_port(env_var)
      raw = ENV.fetch(env_var, nil)
      if raw && !raw.empty?
        n = begin
          Integer(raw, 10)
        rescue StandardError
          nil
        end
        return n if n&.positive?
      end
      # No env override: pick a FREE port (bind :0) rather than a hardcoded
      # default. WS and HTTP control plane are picked independently.
      pick_free_port
    end

    def pick_free_port
      require 'socket'
      s = TCPServer.new('127.0.0.1', 0)
      port = s.addr[1]
      s.close
      port
    end

    def probe_health(harness)
      uri = URI("#{harness.http_url}/__mock__/health")
      Net::HTTP.start(uri.hostname, uri.port,
                      open_timeout: 1, read_timeout: 1) do |http|
        resp = http.get(uri.request_uri)
        return false unless resp.is_a?(Net::HTTPSuccess)

        body = JSON.parse(resp.body)
        return body.is_a?(Hash) && body.key?('schemas_loaded')
      end
    rescue StandardError
      false
    end

    def spawn_server(host, ws_port, http_port)
      cmd = ['python3', '-m', 'mock_relay', '--host', host,
             '--ws-port', ws_port.to_s, '--http-port', http_port.to_s, '--log-level', 'error']
      # File::NULL is portable ('NUL' on Windows); `pgroup:` is a POSIX-only
      # Process.spawn option (Windows raises "wrong exec option symbol: pgroup").
      opts = { out: File::NULL, err: File::NULL, in: File::NULL }
      opts[:pgroup] = true unless Gem.win_platform?
      @pid = Process.spawn(mock_relay_env, *cmd, **opts)
      Process.detach(@pid)
    rescue Errno::ENOENT => e
      raise "mocktest: failed to spawn `python3 -m mock_relay`: #{e.message} " \
            '(set MOCK_RELAY_PORT to use a pre-running instance)'
    end

    # ENV with the adjacency-discovered mock_relay package prepended to PYTHONPATH.
    def mock_relay_env
      pkg_dir = RelayMockTest.discover_porting_sdk_package('mock_relay')
      env = ENV.to_h
      return env unless pkg_dir

      existing = env['PYTHONPATH']
      env['PYTHONPATH'] = existing.nil? || existing.empty? ? pkg_dir : "#{pkg_dir}#{File::PATH_SEPARATOR}#{existing}"
      env
    end

    def wait_for_health(harness)
      deadline = Time.now + STARTUP_TIMEOUT_S
      while Time.now < deadline
        return if probe_health(harness)

        sleep 0.15
      end
      raise 'mocktest: `python3 -m mock_relay` did not become ready within ' \
            "#{STARTUP_TIMEOUT_S}s on #{harness.http_url} " \
            '(clone porting-sdk next to signalwire-ruby so tests can find ' \
            'porting-sdk/test_harness/mock_relay/, or pip install ' \
            'the mock_relay package)'
    end
  end

  module_function

  # Walk this file's directory upward looking for an adjacent
  # ../porting-sdk/test_harness/<name>/<name>/__init__.py.
  def discover_porting_sdk_package(name)
    dir = File.expand_path(__dir__)
    loop do
      parent = File.dirname(dir)
      return nil if parent == dir

      candidate = File.join(parent, 'porting-sdk', 'test_harness', name)
      init = File.join(candidate, name, '__init__.py')
      return candidate if File.file?(init)

      dir = parent
    end
  end

  # Returns the singleton Harness. Lazily probes/spawns the mock-relay server.
  def harness
    Lifecycle.instance.harness
  end

  # Convenience aliases.
  def journal
    harness
  end

  def reset
    harness.reset
  end

  # Spawn a real RelayClient connected to the mock-relay server.
  #
  # Returns a Hash with:
  #   :client     -- the connected SignalWire::Relay::Client
  #   :run_thread -- the background Thread running client.run
  #   :mock       -- a Harness view scoped to THIS client's session id, so the
  #                  test's journal reads/resets/scenarios/pushes see only its
  #                  own frames -- making the shared mock safe under parallel
  #                  (parallelized) test execution. No global reset is needed:
  #                  a brand-new session starts with an empty (scoped) journal.
  #
  # The caller MUST eventually call RelayMockTest.shutdown_client(...) to stop
  # the run loop and join the thread.
  #
  # contexts: defaults to ['default'] to match the Python signalwire_relay_client
  # fixture; pass a different list to test contexts wiring.
  # resume_protocol: when non-nil, stamp the protocol string on the client
  # before run so the connect frame carries it (tests session_restored).
  def client(project: 'test_proj', token: 'test_tok', jwt_token: nil,
             contexts: ['default'], resume_protocol: nil)
    h = harness
    sdk_client = build_sdk_client(h, project, token, jwt_token, contexts)
    sdk_client._set_protocol(resume_protocol) if resume_protocol

    run_thread = spawn_run_thread(sdk_client)
    await_authenticated(sdk_client, run_thread)

    # Scope a per-client harness to the session id the server assigned on the
    # connect handshake (mirrors the TS newRelayClient's per-call harness).
    mock = h.scoped(sdk_client._session_id)
    { client: sdk_client, run_thread: run_thread, mock: mock }
  end

  # Build the SDK client. The ws:// redirect env is already in place from the
  # one-time Lifecycle.start_harness (see the note there) -- this method makes
  # no process-global writes, so it is safe to call from parallel threads.
  def build_sdk_client(harness, project, token, jwt_token, contexts)
    SignalWire::Relay::Client.new(
      project: project, token: token, jwt_token: jwt_token,
      space: harness.relay_host, contexts: contexts
    )
  end

  def spawn_run_thread(sdk_client)
    Thread.new do
      sdk_client.run
    rescue StandardError => e
      warn "[mock_test] client.run raised: #{e.message}"
    end
  end

  # Wait for the connect handshake to complete -- the SDK captures both its
  # protocol string AND the server-assigned session id from the same
  # ConnectResult, so both being set proves the round-trip landed. Reading the
  # client's own state (rather than counting frames in the SHARED journal)
  # keeps readiness race-free under parallel execution.
  def await_authenticated(sdk_client, run_thread)
    deadline = Time.now + 10
    sleep 0.05 until authenticated?(sdk_client) || Time.now > deadline
    return if authenticated?(sdk_client)

    sdk_client.stop
    run_thread.kill
    raise 'mocktest: client did not authenticate within 10s'
  end

  def authenticated?(sdk_client)
    !sdk_client.protocol.nil? && !sdk_client._session_id.nil?
  end

  # Cleanly stop a client started by RelayMockTest.client.
  def shutdown_client(handle)
    return unless handle

    handle[:client].stop
    handle[:run_thread]&.join(3)
  end
end
