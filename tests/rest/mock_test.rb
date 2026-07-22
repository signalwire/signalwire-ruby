# frozen_string_literal: true

# MockTest — Ruby helper for the porting-sdk mock_signalwire HTTP server.
#
# Mirrors the Python conftest fixtures (signalwire_client + mock) and the Go
# package mocktest (pkg/rest/internal/mocktest/mocktest.go) so unit tests can
# exercise the real Ruby SDK code path against a real HTTP server backed by
# SignalWire's 13 OpenAPI specs.
#
# The mock server's lifetime is per-test-process: the first call to
# MockTest.client probes http://127.0.0.1:<port>/__mock__/health and either
# confirms a running server or starts one as a subprocess via Process.spawn.
# Each test resets the journal/scenario state via MockTest.harness.reset.
#
# The default port is 8769 (Ruby's slot in the parallel-rollouts plan).
# Override with MOCK_SIGNALWIRE_PORT if a different mock instance is already
# running.

require 'net/http'
require 'json'
require 'uri'
require 'base64'
require 'securerandom'
require 'singleton'
require_relative '../../lib/signalwire/rest/rest_client'

module MockTest
  # Default port for the Ruby slot in the parallel SDK rollouts.
  # TS=8766, Java=8767, PHP=8768, Ruby=8769, Perl=8770, Rust=8771, C++=8772.

  # Cap how long we wait for an externally-launched server to answer
  # /__mock__/health. The Python in-process harness boots in ~1s, but
  # `python -m mock_signalwire` includes module import + spec loading
  # which can stretch to ~5s on a cold cache.
  STARTUP_TIMEOUT_S = 30

  # JournalEntry mirrors mock_signalwire.journal.JournalEntry over the wire.
  # Body is decoded as a generic Ruby value (Hash for JSON objects, String for
  # form-encoded / non-JSON bodies). Helpers below coerce to the most common
  # shapes used by the test assertions.
  # :method is the HTTP method field name from the wire — keeping it (rather than
  # renaming to dodge the Struct#method override) preserves the journal mirroring.
  # rubocop:disable Lint/StructNewOverride
  JournalEntry = Struct.new(
    :timestamp, :method, :path, :query_params, :headers, :body,
    :matched_route, :response_status,
    keyword_init: true
  ) do
    # rubocop:enable Lint/StructNewOverride
    # Returns the body as a Hash if it's a JSON object, else nil.
    def body_hash
      body.is_a?(Hash) ? body : nil
    end
  end

  # Harness wraps the running mock server. Exposes journal accessors, a
  # helper to push scenario overrides, and a reset hook tests can call from
  # setup / teardown.
  class Harness
    attr_reader :url, :port

    # The unique random project this harness's client authenticates with
    # (+test_proj_<hex>+). Tests that assert on the AccountSid embedded in a
    # LAML path read it from here instead of hard-coding +test_proj+. Empty on
    # an unscoped/raw harness.
    attr_accessor :project

    # When set, +journal+/+last+ return only the requests THIS test's client
    # made -- identified by its +Authorization+ header (Basic +project:token+,
    # with a per-test random project; see {MockTest.client}). REST is pure
    # request/response, so the mock needs no session handshake: each request is
    # self-identifying via its auth header, and filtering the shared global
    # journal by that header makes the suite safe under parallelism without any
    # change to the SDK or the mock server. Empty => unscoped (legacy view,
    # returns every entry -- only correct under serial execution).
    attr_accessor :auth_header

    def initialize(url, port)
      @url         = url
      @port        = port
      @project     = ''
      @auth_header = ''
    end

    # Returns the most recent journal entry for THIS client. Raises if the
    # journal is empty — every test that calls a mock-backed SDK method should
    # produce at least one entry.
    def last
      entries = journal
      raise 'mocktest: journal is empty - SDK call did not reach the mock server' if entries.empty?

      entries.last
    end

    # Returns this client's recorded requests in arrival order. Scoped to this
    # harness's +auth_header+ when set (so a parallel test never sees another
    # test's requests); unscoped harnesses see the whole journal.
    def journal
      arr = JSON.parse(http_get('/__mock__/journal'))
      entries = arr.map { |e| build_entry(e) }
      return entries if @auth_header.nil? || @auth_header.empty?

      entries.select { |e| (e.headers['authorization'] || e.headers['Authorization']) == @auth_header }
    end

    # Clears journal + scenarios on the mock server. A scoped harness leaves
    # the shared journal alone (it only ever reads its own entries, identified
    # by auth header, so there is nothing to clear and a global wipe would race
    # a concurrent test). Unscoped harnesses do the legacy global reset.
    def reset
      return unless @auth_header.nil? || @auth_header.empty?

      http_post('/__mock__/journal/reset')
      http_post('/__mock__/scenarios/reset')
    end

    # Stages a one-shot response override for the route identified by
    # endpoint_id. Scoped to THIS client's auth header (REST's session key) so a
    # concurrent test can't consume it and a stale one can't bleed across tests;
    # an unscoped harness stages it shared.
    def push_scenario(endpoint_id, status:, response:, headers: nil)
      body = { 'status' => status, 'response' => response }
      body['headers'] = headers if headers
      payload = JSON.generate(body)
      q = if @auth_header.nil? || @auth_header.empty?
            ''
          else
            "?session_id=#{URI.encode_www_form_component(@auth_header)}"
          end
      http_post("/__mock__/scenarios/#{endpoint_id}#{q}", payload)
    end

    private

    def build_entry(entry)
      JournalEntry.new(
        timestamp: entry['timestamp'],
        method: entry['method'],
        path: entry['path'],
        query_params: entry['query_params'] || {},
        headers: entry['headers'] || {},
        body: entry['body'],
        matched_route: entry['matched_route'],
        response_status: entry['response_status']
      )
    end

    def http_get(path)
      with_retry do
        uri = URI("#{@url}#{path}")
        Net::HTTP.start(uri.hostname, uri.port) do |http|
          require_success('GET', path, http.get(uri.request_uri))
        end
      end
    end

    def http_post(path, body = nil)
      with_retry do
        uri = URI("#{@url}#{path}")
        Net::HTTP.start(uri.hostname, uri.port) do |http|
          req = Net::HTTP::Post.new(uri.request_uri)
          req['Content-Type'] = 'application/json'
          req.body = body if body
          require_success('POST', path, http.request(req))
        end
      end
    end

    # Raise on a non-2xx response, else return its body.
    def require_success(verb, path, resp)
      raise "mocktest: #{verb} #{path} failed: #{resp.code} #{resp.body}" unless resp.is_a?(Net::HTTPSuccess)

      resp.body
    end

    # Tolerate brief connection refusals while the mock is (re)started by
    # +Lifecycle#respawn_if_dead+. Each retry waits 200ms and triggers a fresh
    # health probe + spawn through the singleton lifecycle. Mirrors the relay
    # harness's +with_retry+ so a transient mock crash under heavy parallel load
    # doesn't cascade into N test errors.
    def with_retry
      attempts = 0
      begin
        yield
      rescue Errno::ECONNREFUSED
        attempts += 1
        raise if attempts > 10

        MockTest::Lifecycle.instance.respawn_if_dead
        sleep 0.2
        retry
      end
    end
  end

  # Singleton lifecycle holder — probe-or-spawn, then reuse.
  class Lifecycle
    include Singleton

    def initialize
      @mu      = Mutex.new
      @started = false
      @harness = nil
      @pid     = nil
    end

    # Returns the singleton Harness, spawning the mock server if needed.
    def harness
      @mu.synchronize do
        return @harness if @started

        @started = true
        @port = resolve_port
        @url  = "http://127.0.0.1:#{@port}"

        @harness = probe_health(@url) ? Harness.new(@url, @port) : spawn_and_build(@url, @port)
      end
    end

    def spawn_and_build(url, port)
      spawn_server(port)
      wait_for_health(url)
      Harness.new(url, port)
    end

    # Idempotent: probe; if the mock is dead, spawn a fresh one and wait for
    # health. Called from the HTTP retry loop so a transient mock crash mid-suite
    # (e.g. under heavy parallel load) doesn't cascade into N test errors.
    # Mirrors RelayMockTest::Lifecycle#respawn_if_dead.
    def respawn_if_dead
      @mu.synchronize do
        url  = @url  || "http://127.0.0.1:#{resolve_port}"
        port = @port || resolve_port
        @url ||= url
        @port ||= port
        return false if probe_health(url)

        spawn_server(port)
        wait_for_health(url)
        true
      end
    end

    private

    def resolve_port
      raw = ENV.fetch('MOCK_SIGNALWIRE_PORT', nil)
      if raw && !raw.empty?
        n = begin
          Integer(raw, 10)
        rescue StandardError
          nil
        end
        return n if n&.positive?
      end
      # No env override: pick a FREE port (bind :0) rather than a hardcoded
      # default that collides with a stale/concurrent mock and hangs the suite.
      pick_free_port
    end

    def pick_free_port
      require 'socket'
      s = TCPServer.new('127.0.0.1', 0)
      port = s.addr[1]
      s.close
      port
    end

    def probe_health(url)
      uri = URI("#{url}/__mock__/health")
      Net::HTTP.start(uri.hostname, uri.port,
                      open_timeout: 2, read_timeout: 2) do |http|
        resp = http.get(uri.request_uri)
        return false unless resp.is_a?(Net::HTTPSuccess)

        body = JSON.parse(resp.body)
        return body.is_a?(Hash) && body.key?('specs_loaded')
      end
    rescue StandardError
      false
    end

    def spawn_server(port)
      cmd = ['python', '-m', 'mock_signalwire', '--host', '127.0.0.1',
             '--port', port.to_s, '--log-level', 'error']
      # Detach: redirect stdio to the null device and (POSIX) put the child in
      # its own process group so signals to the test runner don't cascade. The
      # OS cleans up on exit; we Process.detach so no zombie remains. File::NULL
      # is 'NUL' on Windows / '/dev/null' elsewhere, and `pgroup:` is a POSIX-only
      # spawn option (Windows raises "wrong exec option symbol: pgroup").
      opts = { out: File::NULL, err: File::NULL, in: File::NULL }
      opts[:pgroup] = true unless Gem.win_platform?
      @pid = Process.spawn(spawn_env, *cmd, **opts)
      Process.detach(@pid)
    rescue Errno::ENOENT => e
      raise "mocktest: failed to spawn `python -m mock_signalwire`: #{e.message} " \
            '(set MOCK_SIGNALWIRE_PORT to use a pre-running instance)'
    end

    # Try to inject porting-sdk/test_harness/mock_signalwire/ into PYTHONPATH so
    # `python -m mock_signalwire` resolves without a prior `pip install -e ...`.
    # Adjacency contract: porting-sdk next to signalwire-ruby in ~/src/. When the
    # walk fails we still spawn — the child falls back to the system Python's
    # sys.path, and the readiness probe surfaces a clear timeout if neither works.
    def spawn_env
      pkg_dir = MockTest.discover_porting_sdk_package('mock_signalwire')
      env = ENV.to_h
      return env unless pkg_dir

      current = env['PYTHONPATH']
      env['PYTHONPATH'] = if current.nil? || current.empty?
                            pkg_dir
                          else
                            "#{pkg_dir}#{File::PATH_SEPARATOR}#{current}"
                          end
      env
    end

    def wait_for_health(url)
      deadline = Time.now + STARTUP_TIMEOUT_S
      while Time.now < deadline
        return if probe_health(url)

        sleep 0.15
      end
      raise 'mocktest: `python -m mock_signalwire` did not become ready ' \
            "within #{STARTUP_TIMEOUT_S}s on #{url} " \
            '(clone porting-sdk next to signalwire-ruby so tests can find ' \
            'porting-sdk/test_harness/mock_signalwire/, or pip install ' \
            'the mock_signalwire package)'
    end
  end

  module_function

  # Walk this file's directory upward looking for an adjacent
  # ../porting-sdk/test_harness/<name>/<name>/__init__.py.
  #
  # Returns the absolute path to the directory containing the Python
  # package (the value to put on PYTHONPATH so that `python -m <name>`
  # resolves), or nil when no adjacent porting-sdk is reachable.
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

  # Returns the singleton Harness. Lazily probes/spawns the mock server.
  def harness
    Lifecycle.instance.harness
  end

  # Token shared by every mock-backed REST client (the project varies per
  # test; only the project half of the Basic-auth pair needs to be unique).
  REST_TOKEN = 'test_tok'

  # Returns a handle for a fresh real RestClient pointed at the mock server,
  # plus a per-client harness view scoped to THIS client's requests, so the
  # test reads only its own journal entries — making the shared mock safe under
  # parallelism with no SDK change and no mock-server change.
  #
  # Returns a Hash with:
  #   :client  -- the real SignalWire::REST::RestClient
  #   :mock    -- a Harness view scoped to this client's Authorization header
  #   :project -- the unique random project (+test_proj_<hex>+) this client
  #               authenticates with; tests that assert on the AccountSid in a
  #               LAML path read it from here rather than hard-coding test_proj.
  #
  # Isolation key: each client gets a unique random project
  # (+test_proj_<12 hex>+), so its +Authorization: Basic base64(project:token)+
  # header is unique. The random suffix (not a counter) keeps it collision-free
  # across parallel workers AND separate processes hitting one shared mock. The
  # harness filters the global journal by that header.
  def client
    h = harness
    project = "test_proj_#{SecureRandom.hex(6)}"
    auth_header = "Basic #{Base64.strict_encode64("#{project}:#{REST_TOKEN}")}"

    sdk = SignalWire::REST::RestClient.new(
      project: project, token: REST_TOKEN, base_url: h.url
    )

    # Per-call harness view scoped to this client's auth header. No reset is
    # needed: this client starts with zero entries in the (auth-filtered) view.
    mock = Harness.new(h.url, h.port)
    mock.auth_header = auth_header
    mock.project = project

    { client: sdk, mock: mock, project: project }
  end

  # Convenience method-name aliases so tests can use the journal/scenario
  # helpers without grabbing a Harness instance first. NOTE: these return the
  # UNSCOPED global harness (legacy, single-threaded view). Parallel-safe tests
  # must use the per-client +:mock+ from {client} instead.
  def journal
    harness
  end

  def scenarios
    harness
  end

  # Resets journal + scenarios globally. Parallel-safe tests do NOT call this;
  # their per-client scoped harness starts empty and its #reset is a no-op.
  def reset
    harness.reset
  end
end
