# frozen_string_literal: true

# TlsHarness — shared TLS support for the three cross-port "every SDK does
# verified HTTPS + WSS" capability tests (Ruby slot).
#
# Mirrors the Go template (signalwire-go pkg/{relay,rest,swml}/tls_*_test.go):
#   * locate porting-sdk/test_harness/tls and run the idempotent gen_certs.sh
#     (CA + localhost leaf in certs/: ca.crt / server.crt / server.key),
#   * spawn the shared mock_relay / mock_signalwire in --tls mode (wss:// /
#     https://) on *dedicated* ports so the plain-HTTP/ws mocks the normal
#     mock tests use on the default ports are untouched,
#   * supply real OpenSSL trust stores: a CA-trusting store (positive) and an
#     explicit EMPTY store (negative). REAL verification only — never
#     VERIFY_NONE, never a transport mock.
#
# CA trust is wired idiomatically: Ruby's OpenSSL honors SSL_CERT_FILE for the
# default store, so the WSS path (the SDK relay client seeds its cert store
# from the OpenSSL defaults) trusts the test CA when SSL_CERT_FILE points at
# ca.crt. The REST + server tests build an explicit cert_store from ca.crt,
# which is deterministic and immune to per-process default-store caching.
#
# The negative subtests use an explicit empty OpenSSL::X509::Store (trusts
# nothing) so the rejection is deterministic regardless of env or store
# caching — proving the certificate is genuinely verified.
#
# Tests SKIP cleanly (never fail) when porting-sdk is not adjacent or the
# Python mock cannot be spawned, matching the mocktest adjacency contract.

require 'json'
require 'net/http'
require 'openssl'
require 'socket'
require 'uri'

module TlsHarness
  module_function

  # `python -m mock_signalwire --tls` adds module import + spec loading + the
  # TLS listener, which can stretch to ~15s cold. Keep the budget bounded.
  STARTUP_TIMEOUT_S = 40

  # Test-local TLS mocks pick FREE ports (bind :0) per role rather than
  # hardcoded slots; memoized. Env override (positive int) wins when set.
  @tls_ports = {}
  TLS_PORT_ENV = { ws: 'MOCK_RELAY_TLS_WS_PORT', http: 'MOCK_RELAY_TLS_HTTP_PORT',
                   sw: 'MOCK_SIGNALWIRE_TLS_PORT' }.freeze
  def tls_port(role)
    @tls_ports[role] ||= ((raw = ENV.fetch(TLS_PORT_ENV.fetch(role), '').to_i).positive? ? raw : TlsTransport.free_port)
  end

  # Walk up from this file to an adjacent porting-sdk/test_harness/tls, run the
  # idempotent gen_certs.sh, and return the certs dir. Returns nil when
  # porting-sdk is not adjacent or gen_certs.sh fails (→ the caller skips).
  def certs_dir
    dir = File.expand_path(__dir__)
    loop do
      parent = File.dirname(dir)
      break if parent == dir

      tls_dir = File.join(parent, 'porting-sdk', 'test_harness', 'tls')
      return generate_certs(tls_dir) if File.file?(File.join(tls_dir, 'gen_certs.sh'))

      dir = parent
    end
    nil
  end

  # Run the idempotent gen_certs.sh in tls_dir; return its certs/ path or nil.
  def generate_certs(tls_dir)
    ok = system('bash', File.join(tls_dir, 'gen_certs.sh'), out: File::NULL, err: File::NULL)
    ok ? File.join(tls_dir, 'certs') : nil
  end

  def ca_file
    d = certs_dir
    d && File.join(d, 'ca.crt')
  end

  def server_cert
    d = certs_dir
    d && File.join(d, 'server.crt')
  end

  def server_key
    d = certs_dir
    d && File.join(d, 'server.key')
  end

  # An OpenSSL store that trusts ONLY the throwaway test CA. Used by the
  # positive REST + server assertions — deterministic, no env dependency.
  def trusting_store
    store = OpenSSL::X509::Store.new
    store.add_file(ca_file)
    store
  end

  # An EMPTY OpenSSL store — trusts nothing. Used by the negative subtests so
  # the rejection is unconditional, proving real certificate verification.
  def empty_store
    OpenSSL::X509::Store.new
  end

  # Discover the dir to prepend to PYTHONPATH so `python -m <name>` resolves
  # the shared mock package without a pip install (adjacency contract).
  def discover_pkg(name)
    dir = File.expand_path(__dir__)
    loop do
      parent = File.dirname(dir)
      return nil if parent == dir

      candidate = File.join(parent, 'porting-sdk', 'test_harness', name)
      return candidate if File.file?(File.join(candidate, name, '__init__.py'))

      dir = parent
    end
  end

  # Spawn `python -m mock_signalwire --tls` on the dedicated HTTPS port and
  # poll /__mock__/health (over CA-trusted TLS) until ready. Returns the
  # https:// base URL, or nil when the harness is unavailable. Registers an
  # at_exit kill so the detached child never leaks.
  def start_mock_signalwire
    pkg = discover_pkg('mock_signalwire')
    return nil unless pkg

    base = "https://127.0.0.1:#{tls_port(:sw)}"
    store = trusting_store
    health = "#{base}/__mock__/health"
    return base if TlsTransport.probe_https(health, store)

    pid = TlsTransport.spawn_python(pkg, signalwire_cmd, 'SIGNALWIRE_MOCK_TLS' => '1')
    return nil unless pid

    TlsTransport.poll_until(base, STARTUP_TIMEOUT_S) { TlsTransport.probe_https(health, store) }
  end

  def signalwire_cmd
    ['python3', '-m', 'mock_signalwire', '--host', '127.0.0.1',
     '--port', tls_port(:sw).to_s, '--tls', '--log-level', 'error']
  end

  # Spawn `python -m mock_relay --tls` on the dedicated WS+HTTP port pair and
  # poll the plain-HTTP control plane (TLS mode keeps it HTTP) until ready.
  # Returns a small struct-ish Hash {ws_port:, http_url:}, or nil.
  def start_mock_relay
    pkg = discover_pkg('mock_relay')
    return nil unless pkg

    http_url = "http://127.0.0.1:#{tls_port(:http)}"
    info = { ws_port: tls_port(:ws), http_url: http_url }
    health = "#{http_url}/__mock__/health"
    return info if TlsTransport.probe_http(health)

    pid = TlsTransport.spawn_python(pkg, relay_cmd, 'SIGNALWIRE_MOCK_TLS' => '1')
    return nil unless pid

    TlsTransport.poll_until(info, STARTUP_TIMEOUT_S) { TlsTransport.probe_http(health) }
  end

  def relay_cmd
    ['python3', '-m', 'mock_relay', '--host', '127.0.0.1',
     '--ws-port', tls_port(:ws).to_s, '--http-port', tls_port(:http).to_s,
     '--tls', '--log-level', 'error']
  end

  # Fetch the mock_relay journal (plain-HTTP control plane) and report whether
  # an inbound (SDK→server) frame with the given JSON-RPC method was recorded —
  # wire proof the traffic crossed the WSS link.
  def relay_saw_recv?(http_url, method)
    raw = TlsTransport.http_get_body("#{http_url}/__mock__/journal")
    return false unless raw

    entries = JSON.parse(raw)
    entries.any? { |e| e['direction'] == 'recv' && e['method'] == method }
  rescue StandardError
    false
  end

  # Return the most recent mock_signalwire journal entry (Hash) read over
  # CA-trusted HTTPS, or nil.
  def signalwire_last_journal(base, store)
    raw = TlsTransport.https_get_body("#{base}/__mock__/journal", store)
    return nil unless raw

    arr = JSON.parse(raw)
    arr.last
  rescue StandardError
    nil
  end
end

# Low-level transport + process plumbing for {TlsHarness}. Kept separate so the
# harness stays focused on the TLS capability-test orchestration.
module TlsTransport
  module_function

  # Poll the given block until it returns truthy (yielding `ready_value`) or
  # `timeout_s` elapses (→ nil). Used by both mock launchers.
  def poll_until(ready_value, timeout_s)
    deadline = Time.now + timeout_s
    while Time.now < deadline
      return ready_value if yield

      sleep 0.2
    end
    nil
  end

  def free_port
    s = TCPServer.new('127.0.0.1', 0)
    port = s.addr[1]
    s.close
    port
  end

  def spawn_python(pkg_dir, cmd, extra_env = {})
    env = ENV.to_h
    env['PYTHONPATH'] = prepend_pythonpath(env['PYTHONPATH'], pkg_dir)
    extra_env.each { |k, v| env[k] = v }

    pid = Process.spawn(env, *cmd, **detached_null_spawn_opts)
    Process.detach(pid)
    register_pgroup_kill(pid)
    pid
  rescue Errno::ENOENT
    nil
  end

  # Portable detached-spawn options: stdio to the null device (File::NULL is
  # 'NUL' on Windows) and, on POSIX only, a new process group. `pgroup:` is a
  # POSIX-only Process.spawn option — Windows raises "wrong exec option symbol:
  # pgroup".
  def detached_null_spawn_opts
    opts = { out: File::NULL, err: File::NULL, in: File::NULL }
    opts[:pgroup] = true unless Gem.win_platform?
    opts
  end

  def prepend_pythonpath(current, pkg_dir)
    return pkg_dir if current.nil? || current.empty?

    "#{pkg_dir}#{File::PATH_SEPARATOR}#{current}"
  end

  def register_pgroup_kill(pid)
    at_exit do
      # POSIX: signal the whole process group (negative pid). Windows has no
      # process groups / getpgid — fall back to killing the pid directly.
      if Gem.win_platform?
        Process.kill('KILL', pid)
      else
        Process.kill('TERM', -Process.getpgid(pid))
      end
    rescue StandardError
      # already gone
    end
  end

  def probe_http(url)
    body = http_get_body(url)
    return false unless body

    h = JSON.parse(body)
    h.is_a?(Hash) && (h.key?('schemas_loaded') || h.key?('specs_loaded') || h['status'] == 'ok')
  rescue StandardError
    false
  end

  def probe_https(url, store)
    body = https_get_body(url, store)
    return false unless body

    h = JSON.parse(body)
    h.is_a?(Hash) && (h.key?('specs_loaded') || h['status'] == 'ok')
  rescue StandardError
    false
  end

  def http_get_body(url)
    uri = URI(url)
    Net::HTTP.start(uri.hostname, uri.port,
                    open_timeout: 2, read_timeout: 3) do |http|
      resp = http.get(uri.request_uri)
      resp.is_a?(Net::HTTPSuccess) ? resp.body : nil
    end
  rescue StandardError
    nil
  end

  # HTTPS GET that verifies the peer against the supplied store (VERIFY_PEER).
  # Returns the body String on 2xx, else nil.
  def https_get_body(url, store)
    uri = URI(url)
    resp = verifying_https(uri, store).get(uri.request_uri)
    resp.is_a?(Net::HTTPSuccess) ? resp.body : nil
  rescue StandardError
    nil
  end

  def verifying_https(uri, store)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.cert_store = store
    http.open_timeout = 2
    http.read_timeout = 3
    http
  end
end
