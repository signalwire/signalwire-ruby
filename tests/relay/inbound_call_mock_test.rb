# frozen_string_literal: true

# Real-mock-backed tests for inbound calls (server-initiated).
#
# Translated from
# signalwire-python/tests/unit/relay/test_inbound_call_mock.py.
#
# The mock's POST /__mock__/inbound_call endpoint pushes a
# calling.call.receive frame to the SDK -- exactly what the production
# RELAY server emits when a phone call arrives in a context the SDK
# subscribed to.

require 'minitest/autorun'
require 'securerandom'
require 'timeout'
require_relative 'mock_test'

# Shared fixture + inbound-call/journal helpers for the inbound-call tests.
module RelayInboundCallHelpers
  TIMEOUT = 5
  STATE_DEADLINE = 5

  # Parallelize: each test's client owns a distinct server session + scoped
  # harness, so inbound-call pushes target only that test's client.
  def self.included(base)
    base.parallelize_me!
  end

  def setup
    # No global reset: @mock is scoped to this client's session and starts
    # empty, so the shared mock stays parallel-safe.
    @handle = RelayMockTest.client
    @client = @handle[:client]
    @mock   = @handle[:mock]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
  end

  # A signalwire.event JSON-RPC frame wrapping +event_type+ + inner params.
  def signalwire_event_frame(event_type, params)
    {
      'jsonrpc' => '2.0', 'id' => SecureRandom.uuid, 'method' => 'signalwire.event',
      'params' => { 'event_type' => event_type, 'params' => params }
    }
  end

  # The standard inbound phone device (from/to numbers).
  def inbound_device
    { 'type' => 'phone',
      'params' => { 'from_number' => '+15551110000', 'to_number' => '+15552220000' } }
  end

  def state_push_frame(call_id, call_state, tag: '', direction: 'inbound')
    signalwire_event_frame(
      'calling.call.state',
      'call_id' => call_id, 'node_id' => 'mock-relay-node-1', 'tag' => tag,
      'call_state' => call_state, 'direction' => direction, 'device' => inbound_device
    )
  end

  # Register an on_call handler that maps each inbound call through the given
  # block and pushes the result onto a Queue, fire one inbound call, and return
  # the first mapped result (Timeout-bounded). With no block the Call is
  # returned unchanged.
  def receive_inbound(call_id:, **, &mapper)
    mapper ||= ->(call) { call }
    queue = Queue.new
    @client.on_call(nil) { |call| queue.push(mapper.call(call)) }
    @mock.inbound_call(call_id: call_id, auto_states: ['created'], **)
    Timeout.timeout(TIMEOUT) { queue.pop }
  end

  # Spin (briefly) until +call+ reaches +state+ or the deadline passes.
  def wait_until_state(call, state)
    deadline = Time.now + STATE_DEADLINE
    sleep 0.02 until call.state == state || Time.now > deadline
  end

  # Fire a bare inbound call (created state) without registering a handler.
  def fire_inbound(call_id)
    @mock.inbound_call(call_id: call_id, auto_states: ['created'])
  end

  # Spin (briefly) until +block+ returns truthy or the deadline passes.
  def wait_until(&)
    deadline = Time.now + STATE_DEADLINE
    sleep 0.02 until yield || Time.now > deadline
  end

  # Assert a frame for +method+ was journalled and (optionally) carries call_id.
  def assert_journalled(method, call_id: nil)
    frames = @mock.journal_recv(method: method)

    refute_empty frames, "no #{method} frame in journal"
    last = frames.last.frame['params']
    assert_equal call_id, last['call_id'] if call_id
    last
  end
end

class RelayInboundCallMockTest < Minitest::Test
  include RelayInboundCallHelpers

  # ---- Basic inbound-call handler dispatch -----------------------------

  def test_on_call_handler_fires_with_call_object
    call = receive_inbound(call_id: 'c-handler')

    assert_kind_of SignalWire::Relay::Call, call
    assert_equal 'c-handler', call.call_id
  end

  def test_inbound_call_object_has_correct_call_id_and_direction
    cid, dir = receive_inbound(call_id: 'c-dir') { |c| [c.call_id, c.direction] }

    assert_equal 'c-dir',   cid
    assert_equal 'inbound', dir
  end

  def test_inbound_call_carries_from_to_in_device
    device = receive_inbound(call_id: 'c-from-to',
                             from_number: '+15551112233', to_number: '+15554445566', &:device)
    p = device['params'] || {}

    assert_equal '+15551112233', p['from_number']
    assert_equal '+15554445566', p['to_number']
  end

  def test_inbound_call_initial_state_is_created
    assert_equal 'created', receive_inbound(call_id: 'c-state', &:state)
  end

  # ---- Handler answers -- calling.answer journaled ---------------------

  def test_answer_in_handler_journals_calling_answer
    receive_inbound(call_id: 'c-ans', &:answer)
    sleep 0.1

    assert_journalled('calling.answer', call_id: 'c-ans')
  end

  def test_answer_then_state_event_advances_call_state
    call = receive_inbound(call_id: 'c-ans-state') do |c|
      c.answer
      c
    end
    @mock.push(state_push_frame('c-ans-state', 'answered'))
    wait_until_state(call, 'answered')

    assert_equal 'answered', call.state
  end

  # ---- Handler hangs up / passes ---------------------------------------

  def test_hangup_in_handler_journals_calling_end
    receive_inbound(call_id: 'c-hangup') { |call| call.hangup(reason: 'busy') }
    sleep 0.1
    p = assert_journalled('calling.end', call_id: 'c-hangup')

    assert_equal 'busy', p['reason']
  end

  def test_pass_in_handler_journals_calling_pass
    receive_inbound(call_id: 'c-pass', &:pass_call)
    sleep 0.1

    assert_journalled('calling.pass', call_id: 'c-pass')
  end

  # ---- Multiple inbound calls ------------------------------------------

  def test_multiple_inbound_calls_in_sequence_each_unique_object
    seen_q = Queue.new
    @client.on_call(nil) { |call| seen_q.push(call) }
    fire_inbound('c-seq-1')
    sleep 0.1
    fire_inbound('c-seq-2')

    a = Timeout.timeout(5) { seen_q.pop }
    b = Timeout.timeout(5) { seen_q.pop }

    assert_equal %w[c-seq-1 c-seq-2], [a.call_id, b.call_id].sort
    refute_same a, b
  end

  def test_multiple_inbound_calls_no_state_bleed
    fetch = answer_two_inbound_calls('cb-1', 'cb-2')

    @mock.push(state_push_frame('cb-1', 'answered'))
    wait_until { fetch.call('cb-1')&.state == 'answered' }

    assert_equal 'answered', fetch.call('cb-1').state
    refute_equal 'answered', fetch.call('cb-2').state
  end

  # Register an answering handler, fire both inbound calls, wait for both to be
  # handled, and return a thread-safe ->(id) fetch for the captured Calls.
  def answer_two_inbound_calls(id1, id2)
    by_id = {}
    by_id_mu = Mutex.new
    pushed = register_answering_handler(by_id, by_id_mu)

    fire_inbound(id1)
    sleep 0.05
    fire_inbound(id2)
    2.times { Timeout.timeout(5) { pushed.pop } }
    ->(id) { by_id_mu.synchronize { by_id[id] } }
  end

  # on_call handler that records each call into +store+ (guarded by +mutex+),
  # answers it, and signals completion on the returned Queue.
  def register_answering_handler(store, mutex)
    pushed = Queue.new
    @client.on_call(nil) do |call|
      mutex.synchronize { store[call.call_id] = call }
      call.answer
      pushed.push(true)
    end
    pushed
  end

  # ---- Scripted state sequences ----------------------------------------

  def test_scripted_state_sequence_advances_call
    call = receive_inbound(call_id: 'c-scripted') do |c|
      c.answer
      c
    end
    @mock.push(state_push_frame('c-scripted', 'answered'))
    @mock.push(state_push_frame('c-scripted', 'ended'))
    wait_until_state(call, 'ended')

    assert_equal 'ended', call.state
  end
end

# Handler patterns, scenario_play, wire-shape + no-handler cases. Split from
# the basic-dispatch tests to keep each class within budget.
class RelayInboundCallFlowMockTest < Minitest::Test
  include RelayInboundCallHelpers

  def test_async_handler_completes_normally
    cid = receive_inbound(call_id: 'c-async') do |c|
      sleep 0.01
      c.call_id
    end

    assert_equal 'c-async', cid
  end

  def test_handler_exception_does_not_crash_client
    fire_handler_that_raises('c-raise')
    # Drive a follow-up round-trip to prove the connection survived.
    fire_inbound('c-raise-2')
    sleep 0.2
    sessions = @mock.sessions

    assert_predicate sessions, :any?, 'WebSocket session should still be open after handler raise'
  end

  # Register a handler that signals it fired then raises, fire one inbound
  # call, and wait for the handler to fire.
  def fire_handler_that_raises(call_id)
    fired_q = Queue.new
    @client.on_call(nil) do |_call|
      fired_q.push(true)
      raise 'intentional from handler'
    end
    fire_inbound(call_id)
    Timeout.timeout(5) { fired_q.pop }
    sleep 0.1
  end

  # ---- scenario_play -- full inbound flow ------------------------------

  def test_scenario_play_full_inbound_flow
    captured_q, started_q = register_capturing_answer_handler
    result = @mock.scenario_play(full_inbound_timeline)

    assert_equal 'completed', result['status'], "scenario didn't complete: #{result.inspect}"

    Timeout.timeout(5) { started_q.pop }
    call = Timeout.timeout(5) { captured_q.pop }
    wait_until_state(call, 'ended')

    assert_equal 'ended', call.state
  end

  # on_call handler that captures the call, answers it, and signals start.
  # Returns [captured_queue, started_queue].
  def register_capturing_answer_handler
    captured_q = Queue.new
    started_q = Queue.new
    @client.on_call(nil) do |call|
      captured_q.push(call)
      call.answer
      started_q.push(true)
    end
    [captured_q, started_q]
  end

  def inbound_receive_frame
    signalwire_event_frame(
      'calling.call.receive',
      'call_id' => 'c-scen', 'node_id' => 'mock-relay-node-1', 'tag' => '',
      'call_state' => 'created', 'direction' => 'inbound',
      'device' => inbound_device, 'context' => 'default'
    )
  end

  # The receive -> answer -> answered -> ended scenario timeline.
  def full_inbound_timeline
    [
      { 'push' => { 'frame' => inbound_receive_frame } },
      { 'expect_recv' => { 'method' => 'calling.answer', 'timeout_ms' => 5000 } },
      { 'push'        => { 'frame' => state_push_frame('c-scen', 'answered') } },
      { 'sleep_ms'    => 50 },
      { 'push'        => { 'frame' => state_push_frame('c-scen', 'ended') } }
    ]
  end

  # ---- Wire shape: calling.call.receive --------------------------------

  def test_inbound_call_journal_send_records_calling_call_receive
    receive_inbound(call_id: 'c-wire')
    sends = @mock.journal_send(event_type: 'calling.call.receive')

    refute_empty sends, 'no calling.call.receive frame in journal'
    inner = sends.last.frame['params']['params']

    assert_equal 'c-wire',  inner['call_id']
    assert_equal 'inbound', inner['direction']
  end

  # ---- Inbound without a registered handler ----------------------------

  def test_inbound_without_handler_does_not_crash
    # Use a fresh client so there's no registered handler from prior tests.
    h = RelayMockTest.client
    hmock = h[:mock]
    begin
      hmock.inbound_call(call_id: 'c-nohandler', auto_states: ['created'])
      sleep 0.3
      sessions = hmock.sessions

      assert_predicate sessions, :any?, 'session should still be open without handler'
    ensure
      RelayMockTest.shutdown_client(h)
    end
  end
end
