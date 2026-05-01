# frozen_string_literal: true

# Real-mock-backed tests for SignalWire::Relay::Client connect/auth.
#
# Translated from signalwire-python/tests/unit/relay/test_connect_mock.py.
# These tests boot the shared mock_relay WebSocket server and drive the
# actual SignalWire::Relay::Client.  No mocking of websocket-client-simple;
# the SDK opens a real WebSocket against ws://127.0.0.1:8779.
#
# Each test asserts:
#   1. Behavioral -- what the SDK exposes back to the developer
#      (protocol string set, fields populated, exceptions on error paths).
#   2. Wire -- what the mock journaled (proves the SDK sends the wire
#      shape the production server expects).

require 'minitest/autorun'
require 'json'
require 'net/http'
require 'uri'
require_relative 'mock_test'

class RelayConnectMockTest < Minitest::Test
  def setup
    RelayMockTest.reset
    @handle = nil
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
    RelayMockTest.reset
  end

  # ---- Connect: happy path -----------------------------------------------

  def test_connect_returns_protocol_string
    @handle = RelayMockTest.client
    client = @handle[:client]
    refute_nil client.protocol, 'expected client.protocol to be set after connect'
    assert client.protocol.start_with?('signalwire_'),
           "unexpected protocol: #{client.protocol.inspect}"
  end

  def test_connect_journal_records_signalwire_connect
    @handle = RelayMockTest.client
    connects = RelayMockTest.journal.journal_recv(
      method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT,
    )
    assert_equal 1, connects.size,
                 "expected 1 connect; got #{connects.size}: #{connects.map(&:frame).inspect}"
  end

  def test_connect_journal_carries_project_and_token
    @handle = RelayMockTest.client
    connects = RelayMockTest.journal.journal_recv(
      method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT,
    )
    assert_equal 1, connects.size
    auth = connects[0].frame['params']['authentication']
    assert_equal 'test_proj', auth['project']
    assert_equal 'test_tok',  auth['token']
  end

  def test_connect_journal_carries_contexts
    @handle = RelayMockTest.client
    connects = RelayMockTest.journal.journal_recv(
      method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT,
    )
    assert_equal 1, connects.size
    assert_equal ['default'], connects[0].frame['params']['contexts']
  end

  def test_connect_journal_carries_agent_and_version
    @handle = RelayMockTest.client
    connects = RelayMockTest.journal.journal_recv(
      method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT,
    )
    assert_equal 1, connects.size
    p = connects[0].frame['params']
    assert_equal SignalWire::Relay::AGENT_STRING,     p['agent']
    assert_equal SignalWire::Relay::PROTOCOL_VERSION, p['version']
  end

  def test_connect_journal_event_acks_true
    @handle = RelayMockTest.client
    connects = RelayMockTest.journal.journal_recv(
      method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT,
    )
    assert_equal 1, connects.size
    assert_equal true, connects[0].frame['params']['event_acks']
  end

  # ---- Auth failure paths ------------------------------------------------

  def test_connect_rejects_empty_creds_at_constructor
    old_proj  = ENV.delete('SIGNALWIRE_PROJECT_ID')
    old_token = ENV.delete('SIGNALWIRE_API_TOKEN')
    old_jwt   = ENV.delete('SIGNALWIRE_JWT_TOKEN')
    begin
      assert_raises(ArgumentError) do
        SignalWire::Relay::Client.new(
          project: '', token: '', space: '127.0.0.1:1',
        )
      end
    ensure
      ENV['SIGNALWIRE_PROJECT_ID'] = old_proj  if old_proj
      ENV['SIGNALWIRE_API_TOKEN']  = old_token if old_token
      ENV['SIGNALWIRE_JWT_TOKEN']  = old_jwt   if old_jwt
    end
  end

  def test_unauthenticated_raw_connect_rejected_by_mock
    # Bypass the SDK and drive the WebSocket directly.  The Ruby SDK's
    # constructor refuses empty creds, so we exercise the mock's
    # AUTH_REQUIRED path with a hand-built frame.
    require 'websocket-client-simple'
    h = RelayMockTest.harness
    received = Queue.new
    ws = WebSocket::Client::Simple.connect(h.ws_url) do |sock|
      sock.on(:message) { |msg| received.push(msg.data) }
    end

    # Wait for socket to open before sending.
    deadline = Time.now + 5
    sleep 0.05 until ws.open? || Time.now > deadline
    flunk 'WS did not open' unless ws.open?

    req_id = 'auth-fail-test-1'
    ws.send(JSON.generate(
      'jsonrpc' => '2.0', 'id' => req_id,
      'method'  => 'signalwire.connect',
      'params'  => {
        'version' => SignalWire::Relay::PROTOCOL_VERSION,
        'agent'   => SignalWire::Relay::AGENT_STRING,
        'authentication' => { 'project' => '', 'token' => '' },
      },
    ))

    raw = nil
    begin
      raw = received.pop(true) until raw && JSON.parse(raw)['id'] == req_id
    rescue ThreadError
      # Empty queue: keep polling
    end
    if raw.nil?
      deadline = Time.now + 5
      while Time.now < deadline
        begin
          frame = received.pop(true)
          parsed = JSON.parse(frame)
          if parsed['id'] == req_id
            raw = frame
            break
          end
        rescue ThreadError
          sleep 0.05
        end
      end
    end
    ws.close
    refute_nil raw, 'no response to bad auth received'
    resp = JSON.parse(raw)
    assert resp.key?('error'), "expected error from mock, got: #{resp.inspect}"
    err = resp['error']
    data = err['data'] || {}
    assert_equal 'AUTH_REQUIRED', data['signalwire_error_code']
  end

  # ---- Reconnect with protocol -> session_restored ----------------------

  def test_reconnect_with_protocol_string_includes_protocol_in_frame
    h1 = RelayMockTest.client(project: 'p', token: 't', contexts: ['c1'])
    issued_protocol = h1[:client].protocol
    refute_nil issued_protocol
    RelayMockTest.shutdown_client(h1)

    @handle = RelayMockTest.client(project: 'p', token: 't', contexts: ['c1'],
                              resume_protocol: issued_protocol)
    connects = RelayMockTest.journal.journal_recv(
      method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT,
    )
    resume = connects.select do |e|
      (e.frame['params'] || {})['protocol'] == issued_protocol
    end
    refute_empty resume,
                 "no resume connect carried protocol=#{issued_protocol.inspect}; saw " \
                 "protocols=#{connects.map { |e| (e.frame['params'] || {})['protocol'] }.inspect}"
  end

  def test_reconnect_with_protocol_preserves_protocol_value
    h1 = RelayMockTest.client(project: 'p', token: 't')
    issued_protocol = h1[:client].protocol
    refute_nil issued_protocol
    RelayMockTest.shutdown_client(h1)

    @handle = RelayMockTest.client(project: 'p', token: 't',
                              resume_protocol: issued_protocol)
    # On resume the server confirms the same protocol.
    assert_equal issued_protocol, @handle[:client].protocol
  end

  # ---- Connect: JWT path -------------------------------------------------

  def test_connect_with_jwt_carries_jwt_on_wire
    @handle = RelayMockTest.client(
      project:   'p',  # required by SDK constructor; mock ignores
      token:     'unused',
      jwt_token: 'fake-jwt-eyJ.AaaA.BbB',
    )
    connects = RelayMockTest.journal.journal_recv(
      method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT,
    )
    assert_equal 1, connects.size
    auth = connects[0].frame['params']['authentication']
    assert_equal 'fake-jwt-eyJ.AaaA.BbB', auth['jwt_token']
  end
end
