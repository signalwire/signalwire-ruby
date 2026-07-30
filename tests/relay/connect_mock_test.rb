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

# Shared setup/teardown + WebSocket/journal helpers for the connect test
# classes. The suite is split into topic classes so no single class grows
# unbounded; they all mix in this module.
module RelayConnectHelpers
  # Run this class's tests in parallel threads. Session isolation (each client
  # gets its own server session id + scoped harness) makes the shared mock
  # safe under concurrency, so parallelism stress-proves the isolation.
  def self.included(base)
    base.parallelize_me!
  end

  def setup
    # No global reset: each client's @handle[:mock] is session-scoped and
    # starts empty, so connect-frame counts stay parallel-safe.
    @handle = nil
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
  end

  # Open a raw WS, send +frame+, and return the raw response with matching id.
  def raw_request(req_id, frame)
    received = Queue.new
    ws = open_raw_ws(received)
    ws.send(JSON.generate(frame))
    raw = await_response_with_id(received, req_id)
    ws.close
    raw
  end

  # Open a raw WebSocket to the mock, pushing every message onto +queue+.
  # Flunks if the socket does not open within 5 seconds.
  def open_raw_ws(queue)
    require 'websocket-client-simple'
    ws = WebSocket::Client::Simple.connect(RelayMockTest.harness.ws_url) do |sock|
      sock.on(:message) { |msg| queue.push(msg.data) }
    end
    deadline = Time.now + 5
    sleep 0.05 until ws.open? || Time.now > deadline
    flunk 'WS did not open' unless ws.open?
    ws
  end

  # A signalwire.connect frame with empty credentials (triggers AUTH_REQUIRED).
  def unauthenticated_connect_frame(req_id)
    {
      'jsonrpc' => '2.0', 'id' => req_id,
      'method' => 'signalwire.connect',
      'params' => {
        'version' => SignalWire::Relay::PROTOCOL_VERSION,
        'agent' => SignalWire::Relay::AGENT_STRING,
        'authentication' => { 'project' => '', 'token' => '' }
      }
    }
  end

  # Poll +queue+ up to 5 seconds for a JSON frame whose 'id' matches.
  def await_response_with_id(queue, req_id)
    deadline = Time.now + 5
    while Time.now < deadline
      frame = pop_or_wait(queue) or next
      return frame if JSON.parse(frame)['id'] == req_id
    end
    nil
  end

  # Non-blocking queue pop; sleeps briefly and returns nil when empty.
  def pop_or_wait(queue)
    queue.pop(true)
  rescue ThreadError
    sleep 0.05
    nil
  end

  # Connect once to obtain a protocol, shut down, then reconnect resuming it.
  # Sets @handle to the resumed client; returns the issued protocol.
  def issue_then_reconnect(contexts: nil)
    opts = { project: 'p', token: 't' }
    opts[:contexts] = contexts if contexts
    h1 = RelayMockTest.client(**opts)
    issued_protocol = h1[:client].protocol

    refute_nil issued_protocol
    RelayMockTest.shutdown_client(h1)

    @handle = RelayMockTest.client(**opts, resume_protocol: issued_protocol)
    issued_protocol
  end

  # The signalwire.connect frames THIS test's client sent, read through its
  # session-scoped harness (so a parallel test's connect is never counted).
  def connect_frames
    @handle[:mock].journal_recv(method: SignalWire::Relay::METHOD_SIGNALWIRE_CONNECT)
  end

  def connect_protocol(entry)
    (entry.frame['params'] || {})['protocol']
  end
end

class RelayConnectMockTest < Minitest::Test
  include RelayConnectHelpers

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
    connects = connect_frames

    assert_equal 1, connects.size,
                 "expected 1 connect; got #{connects.size}: #{connects.map(&:frame).inspect}"
  end

  def test_connect_journal_carries_project_and_token
    @handle = RelayMockTest.client
    connects = connect_frames

    assert_equal 1, connects.size
    auth = connects[0].frame['params']['authentication']

    assert_equal 'test_proj', auth['project']
    assert_equal 'test_tok',  auth['token']
  end

  def test_connect_journal_carries_contexts
    @handle = RelayMockTest.client
    connects = connect_frames

    assert_equal 1, connects.size
    assert_equal ['default'], connects[0].frame['params']['contexts']
  end

  def test_connect_journal_carries_agent_and_version
    @handle = RelayMockTest.client
    connects = connect_frames

    assert_equal 1, connects.size
    p = connects[0].frame['params']

    assert_equal SignalWire::Relay::AGENT_STRING,     p['agent']
    assert_equal SignalWire::Relay::PROTOCOL_VERSION, p['version']
  end

  def test_connect_journal_event_acks_true
    @handle = RelayMockTest.client
    connects = connect_frames

    assert_equal 1, connects.size
    assert connects[0].frame['params']['event_acks']
  end

  # ---- Auth failure paths ------------------------------------------------

  # Every credential is INJECTED, so the assertion depends on nothing outside
  # this example. It used to `ENV.delete` the three credential vars and restore
  # them in an `ensure` -- a process-global mutation inside a `parallelize_me!`
  # class, i.e. a window in which every concurrently-running test saw the
  # environment of a test it does not own. (`ensure` restores the var, so the
  # racing threads clobber EACH OTHER's window too: the mutation is the defect,
  # not just the read.)
  #
  # No env var actually needed clearing. `value_or_env` is `explicit || ENV[key]`
  # and `''` is TRUTHY in Ruby, so the explicit `project:`/`token:`/`space:`
  # already win outright; only `jwt_token:` was unset and could fall back to an
  # ambient `SIGNALWIRE_JWT_TOKEN` (which short-circuits validation and would
  # suppress the ArgumentError). Passing `jwt_token: ''` closes that last channel
  # by injection rather than by mutating the world.
  def test_connect_rejects_empty_creds_at_constructor
    assert_raises(ArgumentError) do
      SignalWire::Relay::Client.new(
        project: '', token: '', jwt_token: '', space: '127.0.0.1:1'
      )
    end
  end

  def test_unauthenticated_raw_connect_rejected_by_mock
    # Bypass the SDK and drive the WebSocket directly.  The Ruby SDK's
    # constructor refuses empty creds, so we exercise the mock's
    # AUTH_REQUIRED path with a hand-built frame.
    req_id = 'auth-fail-test-1'
    raw = raw_request(req_id, unauthenticated_connect_frame(req_id))

    refute_nil raw, 'no response to bad auth received'
    resp = JSON.parse(raw)

    assert resp.key?('error'), "expected error from mock, got: #{resp.inspect}"
    data = resp['error']['data'] || {}

    assert_equal 'AUTH_REQUIRED', data['signalwire_error_code']
  end
end

# Reconnect/resume + JWT connect paths.
class RelayReconnectMockTest < Minitest::Test
  include RelayConnectHelpers

  # ---- Reconnect with protocol -> session_restored ----------------------

  def test_reconnect_with_protocol_string_includes_protocol_in_frame
    issued_protocol = issue_then_reconnect(contexts: ['c1'])
    connects = connect_frames
    resume = connects.select { |e| connect_protocol(e) == issued_protocol }

    refute_empty resume,
                 "no resume connect carried protocol=#{issued_protocol.inspect}; saw " \
                 "protocols=#{connects.map { |e| connect_protocol(e) }.inspect}"
  end

  def test_reconnect_with_protocol_preserves_protocol_value
    issued_protocol = issue_then_reconnect
    # On resume the server confirms the same protocol.
    assert_equal issued_protocol, @handle[:client].protocol
  end

  # ---- Connect: JWT path -------------------------------------------------

  def test_connect_with_jwt_carries_jwt_on_wire
    @handle = RelayMockTest.client(
      project: 'p', # required by SDK constructor; mock ignores
      token: 'unused',
      jwt_token: 'fake-jwt-eyJ.AaaA.BbB'
    )
    connects = connect_frames

    assert_equal 1, connects.size
    auth = connects[0].frame['params']['authentication']

    assert_equal 'fake-jwt-eyJ.AaaA.BbB', auth['jwt_token']
  end
end
