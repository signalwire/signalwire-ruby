# frozen_string_literal: true

# TLS capability test #3 of 3: the SDK's own webhook/SWML server serves a
# *real*, verified HTTPS endpoint.
#
# The server-side cross-port quadrant. It starts the SDK server (WEBrick under
# the hood) with the shared porting-sdk self-signed leaf cert (SAN
# localhost/127.0.0.1) in a background thread, then reaches its unauthenticated
# /health route from an in-test net/http client that trusts the test CA over
# https://, asserting a real {"status":"healthy"} body. Running the server in
# a thread + an in-process client keeps the handshake entirely in-test.
#
# Two server paths are covered, both proving HTTPS:
#   * SWMLService#serve(ssl_cert:, ssl_key:, ssl_enabled: true) — the explicit
#     option path (mirrors Python's serve(ssl_cert=, ssl_key=, ssl_enabled=)).
#   * AgentBase#serve via the SWML_SSL_ENABLED / SWML_SSL_CERT_PATH /
#     SWML_SSL_KEY_PATH env vars (mirrors Python's SecurityConfig +
#     WebMixin.serve). This is the env-driven webhook-server path.
#
# CA trust is deterministic: the in-test client uses an explicit OpenSSL store
# loaded from ca.crt (VERIFY_PEER). Each test's negative half uses an explicit
# EMPTY store and asserts the handshake is rejected — proving the server's cert
# is genuinely verified. No VERIFY_NONE.

require 'minitest/autorun'
require 'json'
require 'net/http'
require 'openssl'
require 'socket'
require 'uri'
require_relative '../tls/tls_mock_helper'
require_relative '../../lib/signalwire'
require_relative '../../lib/signalwire/agent/agent_base'

class TlsHttpsServerTest < Minitest::Test
  def setup
    @certs = TlsHarness.certs_dir
    skip 'tls: porting-sdk test certs not available (adjacency)' unless @certs
    @cert = File.join(@certs, 'server.crt')
    @key  = File.join(@certs, 'server.key')
    @ca   = File.join(@certs, 'ca.crt')
    skip 'tls: server cert/key/ca missing' unless [@cert, @key, @ca].all? { |f| File.file?(f) }
    @threads = []
    @servers = []
  end

  def teardown
    @servers.each do |s|
      s.stop
    rescue StandardError
      nil
    end
    @threads.each do |t|
      t.kill
      t.join(2)
    end
    %w[SWML_SSL_ENABLED SWML_SSL_CERT_PATH SWML_SSL_KEY_PATH].each { |k| ENV.delete(k) }
  end

  def free_port
    s = TCPServer.new('127.0.0.1', 0)
    port = s.addr[1]
    s.close
    port
  end

  # Start +svc+ serving HTTPS in a thread (via the supplied serve block) and
  # block until /health answers over CA-trusted TLS. Returns the base URL.
  def start_https(svc, port, &)
    @servers << svc
    @threads << Thread.new do
      yield
    rescue StandardError => e
      warn "[tls_server] serve raised: #{e.class}: #{e.message}"
    end

    base = "https://127.0.0.1:#{port}"
    store = OpenSSL::X509::Store.new
    store.add_file(@ca)
    deadline = Time.now + 12
    loop do
      resp = https_get("#{base}/health", store)
      return [base, resp] if resp

      flunk "server /health never reachable over https on #{base}" if Time.now > deadline
      sleep 0.1
    end
  end

  # Verified HTTPS GET against +store+ (VERIFY_PEER). Returns the Net::HTTP
  # response on 2xx, else nil (so the poll loop retries while booting).
  def https_get(url, store)
    uri = URI(url)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.cert_store = store
    http.open_timeout = 2
    http.read_timeout = 2
    resp = http.get(uri.request_uri)
    resp.is_a?(Net::HTTPSuccess) ? resp : nil
  rescue Errno::ECONNREFUSED, Errno::ECONNRESET
    nil
  rescue OpenSSL::SSL::SSLError
    nil
  end

  def assert_healthy(resp)
    payload = JSON.parse(resp.body)

    assert_equal 'healthy', payload['status'],
                 "verified-HTTPS /health body = #{payload.inspect}, want status=healthy"
  end

  # An empty-store client must be rejected by the server's CA-signed cert.
  def assert_untrusted_rejected(base)
    err = assert_raises(OpenSSL::SSL::SSLError) do
      uri = URI("#{base}/health")
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.cert_store = OpenSSL::X509::Store.new # trusts nothing
      http.open_timeout = 3
      http.read_timeout = 3
      http.get(uri.request_uri)
    end
    assert_match(/certificate verify failed|unknown ca|unable to get local issuer/i,
                 err.message,
                 "expected TLS verification failure; got: #{err.message}")
  end

  # SWMLService over HTTPS via explicit serve(ssl_cert:, ssl_key:, ssl_enabled:).
  def test_swml_service_serves_verified_https
    port = free_port
    svc = SignalWire::SWML::Service.new(name: 'tls-svc', host: '127.0.0.1', port: port)
    base, resp = start_https(svc, port) do
      svc.serve(host: '127.0.0.1', port: port,
                ssl_cert: @cert, ssl_key: @key, ssl_enabled: true)
    end

    assert_healthy(resp)
    assert_untrusted_rejected(base)
  end

  # AgentBase over HTTPS via the SWML_SSL_* env vars (the env-driven webhook
  # server path). The constructor reads the env into the SSL config and
  # AgentBase#serve binds TLS from it — no explicit ssl args at the call site.
  def test_agent_base_serves_verified_https_from_env
    port = free_port
    ENV['SWML_SSL_ENABLED']   = 'true'
    ENV['SWML_SSL_CERT_PATH'] = @cert
    ENV['SWML_SSL_KEY_PATH']  = @key

    agent = SignalWire::AgentBase.new(name: 'tls-agent', host: '127.0.0.1', port: port)
    base, resp = start_https(agent, port) do
      agent.serve(host: '127.0.0.1', port: port)
    end

    assert_healthy(resp)
    assert_untrusted_rejected(base)
  end
end
