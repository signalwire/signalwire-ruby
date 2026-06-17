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
  DEFAULT_WS_PORT   = 8779
  DEFAULT_HTTP_PORT = 9779

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

  # Harness wraps the running mock-relay server. Exposes journal accessors,
  # scenario helpers, and a reset hook tests can call from setup / teardown.
  class Harness
    attr_reader :http_url, :ws_port, :http_port, :host

    def initialize(host:, ws_port:, http_port:)
      @host      = host
      @ws_port   = ws_port
      @http_port = http_port
      @http_url  = "http://#{host}:#{http_port}"
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

    # Returns every entry recorded since the last reset, in arrival order.
    def journal
      raw = http_get('/__mock__/journal')
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

    # Clears journal + scenarios on the mock server.
    def reset
      http_post('/__mock__/journal/reset')
      http_post('/__mock__/scenarios/reset')
    end

    # ------------------------------------------------------------------
    # Scenario plumbing
    # ------------------------------------------------------------------

    # Queue scripted post-RPC events for `method` (FIFO consume-once).
    def arm_method(method, events)
      http_post(
        "/__mock__/scenarios/#{method}",
        JSON.generate(events.is_a?(Array) ? events : [events])
      )
    end

    # Queue a dial-dance scenario (winner state events + final dial event).
    # kwargs: tag, winner_call_id, states, node_id, device, losers, delay_ms.
    def arm_dial(**kwargs)
      http_post(
        '/__mock__/scenarios/dial',
        JSON.generate(stringify_keys(kwargs))
      )
    end

    # ------------------------------------------------------------------
    # Server-initiated pushes
    # ------------------------------------------------------------------

    # Push a single signalwire.event (or other) frame to the SDK.
    def push(frame, session_id: nil)
      path = '/__mock__/push'
      path += "?session_id=#{session_id}" if session_id
      resp = http_post(path, JSON.generate('frame' => frame))
      JSON.parse(resp)
    end

    # Inject an inbound call announcement into one or every session.
    def inbound_call(call_id: nil, from_number: '+15551234567',
                     to_number: '+15559876543', context: 'default',
                     auto_states: nil, delay_ms: 50, session_id: nil)
      body = {
        'from_number' => from_number,
        'to_number' => to_number,
        'context' => context,
        'auto_states' => auto_states || ['created'],
        'delay_ms' => delay_ms
      }
      body['call_id']    = call_id    unless call_id.nil?
      body['session_id'] = session_id unless session_id.nil?
      resp = http_post('/__mock__/inbound_call', JSON.generate(body))
      JSON.parse(resp)
    end

    # Run a scripted timeline of pushes/sleeps/expect_recv on the server.
    def scenario_play(ops)
      resp = http_post('/__mock__/scenario_play', JSON.generate(ops),
                       read_timeout: 30)
      JSON.parse(resp)
    end

    # List active WebSocket session metadata.
    def sessions
      raw = http_get('/__mock__/sessions')
      JSON.parse(raw)['sessions'] || []
    end

    private

    def build_entry(h)
      JournalEntry.new(
        timestamp: h['timestamp'],
        direction: h['direction'],
        method: h['method'],
        request_id: h['request_id'],
        frame: h['frame'] || {},
        connection_id: h['connection_id'],
        session_id: h['session_id']
      )
    end

    def stringify_keys(h)
      return h unless h.is_a?(Hash)

      h.each_with_object({}) do |(k, v), out|
        out[k.to_s] = v.is_a?(Hash) ? stringify_keys(v) : v
      end
    end

    def http_get(path)
      with_retry do
        uri = URI("#{@http_url}#{path}")
        Net::HTTP.start(uri.hostname, uri.port,
                        open_timeout: 5, read_timeout: 10) do |http|
          resp = http.get(uri.request_uri)
          raise "mocktest: GET #{path} failed: #{resp.code} #{resp.body}" unless resp.is_a?(Net::HTTPSuccess)

          resp.body
        end
      end
    end

    def http_post(path, body = nil, read_timeout: 10)
      with_retry do
        uri = URI("#{@http_url}#{path}")
        Net::HTTP.start(uri.hostname, uri.port,
                        open_timeout: 5, read_timeout: read_timeout) do |http|
          req = Net::HTTP::Post.new(uri.request_uri)
          req['Content-Type'] = 'application/json'
          req.body = body if body
          resp = http.request(req)
          raise "mocktest: POST #{path} failed: #{resp.code} #{resp.body}" unless resp.is_a?(Net::HTTPSuccess)

          resp.body || ''
        end
      end
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

        @started   = true
        @ws_port   = resolve_port('MOCK_RELAY_PORT', DEFAULT_WS_PORT)
        @http_port = resolve_port('MOCK_RELAY_HTTP_PORT', DEFAULT_HTTP_PORT)
        @host      = '127.0.0.1'

        @harness = Harness.new(host: @host, ws_port: @ws_port,
                               http_port: @http_port)

        return @harness if probe_health(@harness)

        spawn_server(@host, @ws_port, @http_port)
        wait_for_health(@harness)
        @harness
      end
    end

    # Idempotent: probe; if dead, spawn a fresh mock_relay and wait for
    # health. Called from the HTTP retry loop so a transient mock crash
    # mid-suite doesn't cascade into N test errors.
    def respawn_if_dead
      @mu.synchronize do
        return false if @harness && probe_health(@harness)

        spawn_server(@host || '127.0.0.1',
                     @ws_port   || DEFAULT_WS_PORT,
                     @http_port || DEFAULT_HTTP_PORT)
        wait_for_health(@harness)
        true
      end
    end

    private

    def resolve_port(env_var, default_port)
      raw = ENV.fetch(env_var, nil)
      if raw && !raw.empty?
        n = begin
          Integer(raw, 10)
        rescue StandardError
          nil
        end
        return n if n && n.positive?
      end
      default_port
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
      cmd = ['python3', '-m', 'mock_relay',
             '--host', host,
             '--ws-port', ws_port.to_s,
             '--http-port', http_port.to_s,
             '--log-level', 'error']

      pkg_dir = RelayMockTest.discover_porting_sdk_package('mock_relay')
      env = ENV.to_h
      if pkg_dir
        sep = File::PATH_SEPARATOR
        env['PYTHONPATH'] = if env['PYTHONPATH'].nil? || env['PYTHONPATH'].empty?
                              pkg_dir
                            else
                              "#{pkg_dir}#{sep}#{env['PYTHONPATH']}"
                            end
      end

      @pid = Process.spawn(
        env, *cmd,
        out: '/dev/null', err: '/dev/null', in: '/dev/null',
        pgroup: true
      )
      Process.detach(@pid)
    rescue Errno::ENOENT => e
      raise "mocktest: failed to spawn `python3 -m mock_relay`: #{e.message} " \
            '(set MOCK_RELAY_PORT to use a pre-running instance)'
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
  #   :client    -- the connected SignalWire::Relay::Client
  #   :run_thread -- the background Thread running client.run
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
    # Force the SDK to dial ws://host:ws_port instead of wss://{space}.
    ENV['SIGNALWIRE_RELAY_SCHEME'] = 'ws'
    ENV['SIGNALWIRE_RELAY_HOST']   = h.relay_host

    sdk_client = SignalWire::Relay::Client.new(
      project: project,
      token: token,
      jwt_token: jwt_token,
      space: h.relay_host,
      contexts: contexts
    )
    pre_run_connects = h.journal_recv(method: 'signalwire.connect').size
    sdk_client._set_protocol(resume_protocol) if resume_protocol

    run_thread = Thread.new do
      sdk_client.run
    rescue StandardError => e
      warn "[mock_test] client.run raised: #{e.message}"
    end

    # Wait for the SDK's signalwire.connect to land in the journal AND
    # for client.protocol to be set (protocol is set BEFORE run when
    # resume_protocol is passed, so journal landing is the real signal).
    deadline = Time.now + 10
    while Time.now < deadline
      seen = h.journal_recv(method: 'signalwire.connect').size
      break if seen > pre_run_connects && sdk_client.protocol

      sleep 0.05
    end
    unless sdk_client.protocol &&
           h.journal_recv(method: 'signalwire.connect').size > pre_run_connects
      sdk_client.stop
      run_thread.kill
      raise 'mocktest: client did not authenticate within 10s'
    end

    { client: sdk_client, run_thread: run_thread }
  end

  # Cleanly stop a client started by RelayMockTest.client.
  def shutdown_client(handle)
    return unless handle

    handle[:client].stop
    handle[:run_thread]&.join(3)
  end
end
