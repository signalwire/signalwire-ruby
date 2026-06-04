# frozen_string_literal: true

# TLS capability test #2 of 3: the REST client performs a *real*, verified
# HTTPS request.
#
# One of the cross-port "every SDK does verified HTTPS + WSS" quadrants. It
# boots the shared mock_signalwire in --tls mode (HTTPS, backed by the
# porting-sdk self-signed test CA), points the real
# SignalWire::REST::RestClient (net/http under the hood) at
# https://127.0.0.1:<port>, trusts the test CA via the SDK's +ca_file:+ option,
# and performs a GET against a spec-backed endpoint — asserting a real JSON
# response plus a journal entry.
#
# CA trust is deterministic and idiomatic: the SDK's +ca_file:+ seeds an
# explicit OpenSSL trust store from ca.crt (plus the system defaults, which
# honor SSL_CERT_FILE) and verifies the peer with VERIFY_PEER. A real "data"
# array can only come back over a completed, CA-verified TLS session.
#
# The negative test hits the same https:// endpoint with an explicit EMPTY
# OpenSSL store (trusts nothing) and asserts the handshake is rejected,
# proving the certificate is genuinely verified — no VERIFY_NONE, no mock.

require 'minitest/autorun'
require 'json'
require 'net/http'
require 'openssl'
require 'uri'
require_relative '../tls/tls_mock_helper'
require_relative '../../lib/signalwire/rest/rest_client'

class TlsHttpsRestTest < Minitest::Test
  def setup
    @base = TlsHarness.start_mock_signalwire
    skip 'tls: porting-sdk mock_signalwire --tls not available (adjacency/spawn)' unless @base
    @ca = TlsHarness.ca_file
    skip 'tls: porting-sdk test CA not available' unless @ca && File.file?(@ca)
  end

  # Positive: a CA-trusting REST client GETs a spec-backed collection over
  # verified HTTPS, gets a real JSON "data" array, and the mock journals the
  # GET (wire proof the request reached the server over the TLS link).
  def test_rest_client_gets_over_verified_https
    client = SignalWire::REST::RestClient.new(
      project: 'test_proj', token: 'test_tok',
      base_url: @base, ca_file: @ca,
    )

    body = client.addresses.list(page_size: 5)
    assert_kind_of Hash, body
    assert body.key?('data'),
           "verified-HTTPS response missing 'data' key; got keys #{body.keys.inspect}"
    assert_kind_of Array, body['data']

    last = TlsHarness.signalwire_last_journal(@base, TlsHarness.trusting_store)
    refute_nil last, 'mock journal empty — the HTTPS GET did not reach the mock'
    assert_equal 'GET', last['method']
    assert_equal '/api/relay/rest/addresses', last['path'],
                 "unexpected journaled path: #{last['path'].inspect}"
  end

  # Negative: a client that trusts nothing (explicit empty OpenSSL store) must
  # be rejected by the same https:// endpoint, proving real certificate
  # verification is in force.
  def test_untrusted_https_client_is_rejected
    uri = URI("#{@base}/__mock__/health")
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.cert_store = TlsHarness.empty_store    # trusts nothing
    http.open_timeout = 3
    http.read_timeout = 3

    err = assert_raises(OpenSSL::SSL::SSLError) do
      http.get(uri.request_uri)
    end
    assert_match(/certificate verify failed|unknown ca|unable to get local issuer/i,
                 err.message,
                 "expected a TLS verification failure; got: #{err.message}")
  end
end
