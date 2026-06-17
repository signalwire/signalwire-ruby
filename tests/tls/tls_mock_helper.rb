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

  # Dedicated ports for the TLS capability tests — distinct from every other
  # mock test's default slot so the two never collide in one `rake test` run.
  TLS_RELAY_WS_PORT   = 18_775
  TLS_RELAY_HTTP_PORT = 19_775
  TLS_SIGNALWIRE_PORT = 18_766

  # Walk up from this file to an adjacent porting-sdk/test_harness/tls, run the
  # idempotent gen_certs.sh, and return the certs dir. Returns nil when
  # porting-sdk is not adjacent or gen_certs.sh fails (→ the caller skips).
  def certs_dir
    dir = File.expand_path(__dir__)
    loop do
      parent = File.dirname(dir)
      break if parent == dir

      tls_dir = File.join(parent, 'porting-sdk', 'test_harness', 'tls')
      gen = File.join(tls_dir, 'gen_certs.sh')
      if File.file?(gen)
        ok = system('bash', gen, out: File::NULL, err: File::NULL)
        return ok ? File.join(tls_dir, 'certs') : nil
      end
      dir = parent
    end
    nil
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

    base = "https://127.0.0.1:#{TLS_SIGNALWIRE_PORT}"
    store = trusting_store
    return base if probe_https("#{base}/__mock__/health", store)

    pid = spawn_python(
      pkg,
      ['python3', '-m', 'mock_signalwire',
       '--host', '127.0.0.1', '--port', TLS_SIGNALWIRE_PORT.to_s,
       '--tls', '--log-level', 'error'],
      'SIGNALWIRE_MOCK_TLS' => '1'
    )
    return nil unless pid

    deadline = Time.now + STARTUP_TIMEOUT_S
    while Time.now < deadline
      return base if probe_https("#{base}/__mock__/health", store)

      sleep 0.2
    end
    nil
  end

  # Spawn `python -m mock_relay --tls` on the dedicated WS+HTTP port pair and
  # poll the plain-HTTP control plane (TLS mode keeps it HTTP) until ready.
  # Returns a small struct-ish Hash {ws_port:, http_url:}, or nil.
  def start_mock_relay
    pkg = discover_pkg('mock_relay')
    return nil unless pkg

    http_url = "http://127.0.0.1:#{TLS_RELAY_HTTP_PORT}"
    info = { ws_port: TLS_RELAY_WS_PORT, http_url: http_url }
    return info if probe_http("#{http_url}/__mock__/health")

    pid = spawn_python(
      pkg,
      ['python3', '-m', 'mock_relay',
       '--host', '127.0.0.1',
       '--ws-port', TLS_RELAY_WS_PORT.to_s,
       '--http-port', TLS_RELAY_HTTP_PORT.to_s,
       '--tls', '--log-level', 'error'],
      'SIGNALWIRE_MOCK_TLS' => '1'
    )
    return nil unless pid

    deadline = Time.now + STARTUP_TIMEOUT_S
    while Time.now < deadline
      return info if probe_http("#{http_url}/__mock__/health")

      sleep 0.2
    end
    nil
  end

  # Fetch the mock_relay journal (plain-HTTP control plane) and report whether
  # an inbound (SDK→server) frame with the given JSON-RPC method was recorded —
  # wire proof the traffic crossed the WSS link.
  def relay_saw_recv?(http_url, method)
    raw = http_get_body("#{http_url}/__mock__/journal")
    return false unless raw

    entries = JSON.parse(raw)
    entries.any? { |e| e['direction'] == 'recv' && e['method'] == method }
  rescue StandardError
    false
  end

  # Return the most recent mock_signalwire journal entry (Hash) read over
  # CA-trusted HTTPS, or nil.
  def signalwire_last_journal(base, store)
    raw = https_get_body("#{base}/__mock__/journal", store)
    return nil unless raw

    arr = JSON.parse(raw)
    arr.last
  rescue StandardError
    nil
  end

  # --- internals -----------------------------------------------------------

  def free_port
    s = TCPServer.new('127.0.0.1', 0)
    port = s.addr[1]
    s.close
    port
  end

  def spawn_python(pkg_dir, cmd, extra_env = {})
    env = ENV.to_h
    sep = File::PATH_SEPARATOR
    env['PYTHONPATH'] = if env['PYTHONPATH'].nil? || env['PYTHONPATH'].empty?
                          pkg_dir
                        else
                          "#{pkg_dir}#{sep}#{env['PYTHONPATH']}"
                        end
    extra_env.each { |k, v| env[k] = v }

    pid = Process.spawn(env, *cmd,
                        out: File::NULL, err: File::NULL, in: File::NULL,
                        pgroup: true)
    Process.detach(pid)
    at_exit do
      Process.kill('TERM', -Process.getpgid(pid))
    rescue StandardError
      # already gone
    end
    pid
  rescue Errno::ENOENT
    nil
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
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.cert_store = store
    http.open_timeout = 2
    http.read_timeout = 3
    resp = http.get(uri.request_uri)
    resp.is_a?(Net::HTTPSuccess) ? resp.body : nil
  rescue StandardError
    nil
  end
end
