# frozen_string_literal: true

# TLS capability test #1 of 3: the RELAY client performs a *real*, verified
# WSS handshake.
#
# One of the cross-port "every SDK does verified HTTPS + WSS" quadrants. It
# boots the shared mock_relay in --tls mode (wss:// backed by the porting-sdk
# self-signed test CA), points the real SignalWire::Relay::Client (built on
# websocket-client-simple) at wss://127.0.0.1:<port>, trusts the test CA, and
# drives the full connect + authenticate handshake.
#
# CA trust is wired idiomatically: SSL_CERT_FILE → ca.crt (Ruby's OpenSSL
# default store honors it) AND the explicit SIGNALWIRE_RELAY_SSL_CA_FILE hook
# the SDK reads when building its WSS trust store. The SDK now forces
# VERIFY_PEER for wss:// (websocket-client-simple otherwise leaves a fresh
# SSLContext at VERIFY_NONE, silently accepting any cert) — so the
# server-issued RELAY protocol string can only come back over a genuinely
# verified TLS session. No VERIFY_NONE, no transport mock.
#
# The negative test points the SDK at the same wss:// endpoint with an empty
# trust store (SSL_CERT_FILE=/dev/null, no CA-file hook) and asserts the
# handshake is rejected — proving real verification is in force.

require 'minitest/autorun'
require 'json'
require_relative '../tls/tls_mock_helper'
require_relative '../../lib/signalwire/relay/client'

class TlsWssRelayTest < Minitest::Test
  def setup
    @mock = TlsHarness.start_mock_relay
    skip 'tls: porting-sdk mock_relay --tls not available (adjacency/spawn)' unless @mock
    @ca = TlsHarness.ca_file
    skip 'tls: porting-sdk test CA not available' unless @ca && File.file?(@ca)
    @handle = nil
    # Snapshot env we mutate so the rest of the suite is unaffected.
    @saved = ENV.to_h.slice('SSL_CERT_FILE', 'SIGNALWIRE_RELAY_SCHEME',
                            'SIGNALWIRE_RELAY_HOST', 'SIGNALWIRE_RELAY_SSL_CA_FILE')
  end

  def teardown
    if @handle
      begin
        @handle[:client].stop
      rescue StandardError
        nil
      end
      @handle[:run_thread]&.kill
      @handle[:run_thread]&.join(2)
    end
    %w[SSL_CERT_FILE SIGNALWIRE_RELAY_SCHEME SIGNALWIRE_RELAY_HOST
       SIGNALWIRE_RELAY_SSL_CA_FILE].each { |k| ENV.delete(k) }
    @saved&.each { |k, v| ENV[k] = v }
  end

  # Connect a real SignalWire::Relay::Client to wss://<mock>, returning a
  # {client:, run_thread:} handle once it has authenticated (protocol set).
  # Raises on timeout. ca_file: nil reproduces an untrusted client.
  def connect_relay(ca_file:)
    if ca_file
      ENV['SSL_CERT_FILE'] = ca_file
      ENV['SIGNALWIRE_RELAY_SSL_CA_FILE'] = ca_file
    else
      ENV['SSL_CERT_FILE'] = File::NULL # empty default store
      ENV.delete('SIGNALWIRE_RELAY_SSL_CA_FILE')
    end
    ENV['SIGNALWIRE_RELAY_SCHEME'] = 'wss'
    ENV['SIGNALWIRE_RELAY_HOST']   = "127.0.0.1:#{@mock[:ws_port]}"

    client = SignalWire::Relay::Client.new(
      project: 'test_proj', token: 'test_tok',
      space: "127.0.0.1:#{@mock[:ws_port]}", contexts: ['default']
    )
    run_thread = Thread.new do
      client.run
    rescue StandardError => e
      warn "[tls_wss] client.run raised: #{e.class}: #{e.message}"
    end
    deadline = Time.now + 12
    sleep 0.05 until (client.protocol && !client.protocol.empty?) || Time.now > deadline
    { client: client, run_thread: run_thread }
  end

  # Positive: a CA-trusting RELAY client authenticates over verified wss://,
  # and the mock journals the inbound signalwire.connect frame (wire proof the
  # credential exchange crossed the TLS link).
  def test_relay_client_authenticates_over_verified_wss
    @handle = connect_relay(ca_file: @ca)
    client = @handle[:client]

    refute_nil client.protocol,
               'expected RELAY protocol after wss authenticate; TLS connect never completed'
    assert client.protocol.start_with?('signalwire_'),
           "unexpected protocol over wss: #{client.protocol.inspect}"

    assert TlsHarness.relay_saw_recv?(@mock[:http_url], 'signalwire.connect'),
           'mock journal has no recv signalwire.connect frame over the WSS connection'
  end

  # Negative: an untrusted client (empty trust store, no CA hook) must NOT be
  # able to authenticate — the wss:// handshake is rejected, so no protocol is
  # ever issued. This proves the SDK genuinely verifies the server cert
  # (VERIFY_PEER), not VERIFY_NONE.
  def test_untrusted_relay_client_cannot_complete_wss
    @handle = connect_relay(ca_file: nil)
    client = @handle[:client]

    assert(client.protocol.nil? || client.protocol.empty?,
           "untrusted wss client unexpectedly authenticated (protocol=#{client.protocol.inspect}); " \
           'certificate verification is not being enforced')
  end
end
