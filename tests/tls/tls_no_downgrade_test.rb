# frozen_string_literal: true

# TLS capability test: an https:// / wss:// client NEVER silently falls back to
# cleartext.
#
# The three existing tests/tls tests prove the SDK completes a verified HTTPS
# request and a verified WSS handshake, and that an untrusted client is
# rejected. They do NOT cover the failure this test exists for: a client the
# user configured for TLS that quietly sends the request in the clear. The user
# asked for encryption, did not get it, and was never told.
#
# Three independent probes, all driving the REAL clients against a REAL socket:
#
#  1. REST, https:// -> plain-HTTP listener. The client must RAISE. If it
#     downgraded, the listener would receive a readable "GET /... HTTP/1.1"
#     request line and the client would get a 200 back. The listener records
#     what it actually received, so a downgrade is caught as CLEARTEXT ON THE
#     WIRE, not merely as a missing exception.
#  2. REST default scheme. A client constructed with a real space name (no
#     base_url, no env override) must address https://, so the ordinary
#     no-configuration path is encrypted.
#  3. RELAY default scheme. Same question for the WebSocket transport:
#     SIGNALWIRE_RELAY_SCHEME unset must resolve to wss://, not ws://.
#
# Probe 1 is the load-bearing one and is behavioural end-to-end; 2 and 3 close
# the "the secure thing is the default" half.

require 'minitest/autorun'
require 'socket'
require 'timeout'
require_relative '../../lib/signalwire/rest/rest_client'
require_relative '../../lib/signalwire/relay/client'

class TlsNoDowngradeTest < Minitest::Test
  # A one-shot plain-HTTP listener. Accepts a single connection, reads whatever
  # bytes arrive, answers 200 with a JSON body, and records the raw first bytes
  # so the test can tell a TLS ClientHello from a cleartext request line.
  class PlainHttpProbe
    attr_reader :thread

    def initialize
      @server = TCPServer.new('127.0.0.1', 0)
      @mutex  = Mutex.new
      @seen   = nil
      @thread = Thread.new { accept_one }
    end

    def port = @server.addr[1]

    def seen
      @mutex.synchronize { @seen }
    end

    def close
      @thread.kill
      @thread.join(2)
      @server.close unless @server.closed?
    end

    private

    # Accept one connection, capture the opening bytes, and reply with a valid
    # plain-HTTP 200 so a downgraded client would SUCCEED (making the downgrade
    # unmistakable rather than an ambiguous connection error).
    def accept_one
      sock = @server.accept
      first = read_opening_bytes(sock)
      @mutex.synchronize { @seen = first }
      body = '{"data":[]}'
      sock.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
                 "Content-Length: #{body.bytesize}\r\n\r\n#{body}")
      sock.close
    rescue StandardError
      nil
    end

    # Read up to 512 bytes with a short deadline. A TLS client sends a binary
    # ClientHello (first byte 0x16); a cleartext HTTP client sends "GET ...".
    def read_opening_bytes(sock)
      Timeout.timeout(3) { sock.readpartial(512) }
    rescue StandardError
      nil
    end
  end

  def setup
    @probe = PlainHttpProbe.new
  end

  def teardown
    @probe&.close
  end

  # PROBE 1 (behavioural): a REST client configured with an https:// base_url
  # pointed at a PLAIN-HTTP listener must fail. It must not retry in the clear,
  # and no cleartext HTTP request line may reach the socket.
  def test_https_rest_client_never_downgrades_to_cleartext
    client = SignalWire::REST::RestClient.new(
      project: 'test_proj', token: 'test_tok',
      base_url: "https://127.0.0.1:#{@probe.port}"
    )

    assert_raises(SignalWire::REST::SignalWireRestError) { client.addresses.list }
    _assert_no_cleartext_request
  end

  # The listener must never have seen a readable HTTP request line. Either it
  # saw nothing (handshake aborted) or it saw a TLS record (0x16 = handshake).
  def _assert_no_cleartext_request
    seen = @probe.seen
    return if seen.nil? || seen.empty?

    refute_match(/\A(GET|POST|PUT|PATCH|DELETE) /, seen,
                 'SILENT DOWNGRADE: an https:// REST client sent a CLEARTEXT HTTP ' \
                 "request to a plain listener. First bytes: #{seen[0, 64].inspect}")
    assert_equal 0x16, seen.bytes.first,
                 'expected a TLS ClientHello (0x16) on the wire from an https:// client; ' \
                 "got: #{seen[0, 16].inspect}"
  end

  # PROBE 2: with no base_url and no env override, an ordinary space name must
  # resolve to https:// — TLS is the DEFAULT, not an opt-in.
  def test_rest_default_scheme_is_https
    saved = ENV.fetch('SIGNALWIRE_REST_BASE_URL', nil)
    ENV.delete('SIGNALWIRE_REST_BASE_URL')
    http = SignalWire::REST::HttpClient.new('p', 't', 'acme')

    assert_match(%r{\Ahttps://}, http.inspect[/base_url="([^"]+)"/, 1],
                 'REST client defaulted to a non-TLS scheme for a normal space')
  ensure
    saved.nil? ? ENV.delete('SIGNALWIRE_REST_BASE_URL') : ENV['SIGNALWIRE_REST_BASE_URL'] = saved
  end

  # PROBE 3: with SIGNALWIRE_RELAY_SCHEME unset, the RELAY transport must
  # resolve to wss:// — the WebSocket default is encrypted too.
  def test_relay_default_scheme_is_wss
    saved = ENV.fetch('SIGNALWIRE_RELAY_SCHEME', nil)
    ENV.delete('SIGNALWIRE_RELAY_SCHEME')
    client = SignalWire::Relay::Client.new(project: 'p', token: 't', space: 'acme.signalwire.com')

    assert_equal 'wss', client.send(:relay_scheme),
                 'RELAY client defaulted to a non-TLS scheme'
  ensure
    saved.nil? ? ENV.delete('SIGNALWIRE_RELAY_SCHEME') : ENV['SIGNALWIRE_RELAY_SCHEME'] = saved
  end
end
