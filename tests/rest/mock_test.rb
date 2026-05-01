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
require 'singleton'
require_relative '../../lib/signalwire/rest/rest_client'

module MockTest
  # Default port for the Ruby slot in the parallel SDK rollouts.
  # TS=8766, Java=8767, PHP=8768, Ruby=8769, Perl=8770, Rust=8771, C++=8772.
  DEFAULT_PORT = 8769

  # Cap how long we wait for an externally-launched server to answer
  # /__mock__/health. The Python in-process harness boots in ~1s, but
  # `python -m mock_signalwire` includes module import + spec loading
  # which can stretch to ~5s on a cold cache.
  STARTUP_TIMEOUT_S = 30

  # JournalEntry mirrors mock_signalwire.journal.JournalEntry over the wire.
  # Body is decoded as a generic Ruby value (Hash for JSON objects, String for
  # form-encoded / non-JSON bodies). Helpers below coerce to the most common
  # shapes used by the test assertions.
  JournalEntry = Struct.new(
    :timestamp, :method, :path, :query_params, :headers, :body,
    :matched_route, :response_status,
    keyword_init: true,
  ) do
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

    def initialize(url, port)
      @url  = url
      @port = port
    end

    # Returns the most recent journal entry. Raises if the journal is empty —
    # every test that calls a mock-backed SDK method should produce at least
    # one entry.
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

    # Clears journal + scenarios on the mock server. Tests typically call
    # this in #setup; #teardown calls it again to keep accidental leftover
    # state from a panic from leaking into the next test.
    def reset
      http_post('/__mock__/journal/reset')
      http_post('/__mock__/scenarios/reset')
    end

    # Stages a one-shot response override for the route identified by
    # endpoint_id. The status + body returned here will be served the next
    # time the route is hit; subsequent hits fall back to spec synthesis.
    def push_scenario(endpoint_id, status:, response:)
      payload = JSON.generate('status' => status, 'response' => response)
      http_post("/__mock__/scenarios/#{endpoint_id}", payload)
    end

    private

    def build_entry(h)
      JournalEntry.new(
        timestamp:       h['timestamp'],
        method:          h['method'],
        path:            h['path'],
        query_params:    h['query_params'] || {},
        headers:         h['headers'] || {},
        body:            h['body'],
        matched_route:   h['matched_route'],
        response_status: h['response_status'],
      )
    end

    def http_get(path)
      uri = URI("#{@url}#{path}")
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        resp = http.get(uri.request_uri)
        unless resp.is_a?(Net::HTTPSuccess)
          raise "mocktest: GET #{path} failed: #{resp.code} #{resp.body}"
        end

        resp.body
      end
    end

    def http_post(path, body = nil)
      uri = URI("#{@url}#{path}")
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        req = Net::HTTP::Post.new(uri.request_uri)
        req['Content-Type'] = 'application/json'
        req.body = body if body
        resp = http.request(req)
        unless resp.is_a?(Net::HTTPSuccess)
          raise "mocktest: POST #{path} failed: #{resp.code} #{resp.body}"
        end

        resp.body
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
        port = resolve_port
        url  = "http://127.0.0.1:#{port}"

        if probe_health(url)
          @harness = Harness.new(url, port)
          return @harness
        end

        spawn_server(port)
        wait_for_health(url)
        @harness = Harness.new(url, port)
        @harness
      end
    end

    private

    def resolve_port
      raw = ENV['MOCK_SIGNALWIRE_PORT']
      if raw && !raw.empty?
        n = Integer(raw, 10) rescue nil
        return n if n && n.positive?
      end
      DEFAULT_PORT
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
      cmd = ['python', '-m', 'mock_signalwire',
             '--host', '127.0.0.1',
             '--port', port.to_s,
             '--log-level', 'error']
      # Try to inject porting-sdk/test_harness/mock_signalwire/ into
      # PYTHONPATH so `python -m mock_signalwire` resolves without a prior
      # `pip install -e ...`. Adjacency contract: porting-sdk next to
      # signalwire-ruby in ~/src/. When the walk fails we still spawn —
      # the child falls back to whatever is on the system Python's
      # sys.path, and the readiness probe surfaces a clear timeout error
      # if neither mode is available.
      pkg_dir = MockTest.discover_porting_sdk_package('mock_signalwire')
      env = ENV.to_h
      if pkg_dir
        sep = File::PATH_SEPARATOR
        env['PYTHONPATH'] = env['PYTHONPATH'].nil? || env['PYTHONPATH'].empty? \
          ? pkg_dir : "#{pkg_dir}#{sep}#{env['PYTHONPATH']}"
      end
      # Detach: redirect stdio to /dev/null and put the child in its own
      # process group so signals to the test runner don't cascade. The OS
      # cleans up on exit; we explicitly Process.detach so no zombie remains.
      @pid = Process.spawn(
        env,
        *cmd,
        out: '/dev/null',
        err: '/dev/null',
        in:  '/dev/null',
        pgroup: true,
      )
      Process.detach(@pid)
    rescue Errno::ENOENT => e
      raise "mocktest: failed to spawn `python -m mock_signalwire`: #{e.message} " \
            "(set MOCK_SIGNALWIRE_PORT to use a pre-running instance)"
    end

    def wait_for_health(url)
      deadline = Time.now + STARTUP_TIMEOUT_S
      while Time.now < deadline
        return if probe_health(url)

        sleep 0.15
      end
      raise "mocktest: `python -m mock_signalwire` did not become ready " \
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

  # Returns a fresh real RestClient pointed at the mock server. The mock
  # accepts any non-empty Basic Auth header — credentials are
  # 'test_proj' / 'test_tok' to match the Python signalwire_client fixture.
  def client
    h = harness
    SignalWire::REST::RestClient.new(
      project:  'test_proj',
      token:    'test_tok',
      base_url: h.url,
    )
  end

  # Convenience method-name aliases so tests can use the journal/scenario
  # helpers without grabbing a Harness instance first.
  def journal
    harness
  end

  def scenarios
    harness
  end

  # Resets journal + scenarios. Tests call this in setup so each test starts
  # with a clean slate.
  def reset
    harness.reset
  end
end
