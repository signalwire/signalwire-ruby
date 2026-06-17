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

class RelayInboundCallMockTest < Minitest::Test
  def setup
    RelayMockTest.reset
    @handle = RelayMockTest.client
    @client = @handle[:client]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
    RelayMockTest.reset
  end

  # ---- Helpers ---------------------------------------------------------

  def state_push_frame(call_id, call_state, tag: '', direction: 'inbound')
    {
      'jsonrpc' => '2.0',
      'id' => SecureRandom.uuid,
      'method' => 'signalwire.event',
      'params' => {
        'event_type' => 'calling.call.state',
        'params' => {
          'call_id' => call_id,
          'node_id' => 'mock-relay-node-1',
          'tag' => tag,
          'call_state' => call_state,
          'direction' => direction,
          'device' => {
            'type' => 'phone',
            'params' => {
              'from_number' => '+15551110000',
              'to_number' => '+15552220000'
            }
          }
        }
      }
    }
  end

  # ---- Basic inbound-call handler dispatch -----------------------------

  def test_on_call_handler_fires_with_call_object
    seen_q = Queue.new
    @client.on_call do |call|
      seen_q.push(call)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-handler', auto_states: ['created'])
    call = Timeout.timeout(5) { seen_q.pop }

    assert_kind_of SignalWire::Relay::Call, call
    assert_equal 'c-handler', call.call_id
  end

  def test_inbound_call_object_has_correct_call_id_and_direction
    seen_q = Queue.new
    @client.on_call do |call|
      seen_q.push([call.call_id, call.direction])
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-dir', auto_states: ['created'])
    cid, dir = Timeout.timeout(5) { seen_q.pop }

    assert_equal 'c-dir',   cid
    assert_equal 'inbound', dir
  end

  def test_inbound_call_carries_from_to_in_device
    seen_q = Queue.new
    @client.on_call do |call|
      seen_q.push(call.device)
    end
    RelayMockTest.journal.inbound_call(
      call_id: 'c-from-to',
      from_number: '+15551112233',
      to_number: '+15554445566',
      auto_states: ['created']
    )
    device = Timeout.timeout(5) { seen_q.pop }
    p = device['params'] || {}

    assert_equal '+15551112233', p['from_number']
    assert_equal '+15554445566', p['to_number']
  end

  def test_inbound_call_initial_state_is_created
    seen_q = Queue.new
    @client.on_call do |call|
      seen_q.push(call.state)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-state', auto_states: ['created'])

    assert_equal 'created', Timeout.timeout(5) { seen_q.pop }
  end

  # ---- Handler answers -- calling.answer journaled ---------------------

  def test_answer_in_handler_journals_calling_answer
    answered = Queue.new
    @client.on_call do |call|
      call.answer
      answered.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-ans', auto_states: ['created'])
    Timeout.timeout(5) { answered.pop }
    sleep 0.1
    answers = RelayMockTest.journal.journal_recv(method: 'calling.answer')

    refute_empty answers, 'no calling.answer frame in journal'
    assert_equal 'c-ans', answers.last.frame['params']['call_id']
  end

  def test_answer_then_state_event_advances_call_state
    captured_q = Queue.new
    handler_done = Queue.new
    @client.on_call do |call|
      captured_q.push(call)
      call.answer
      handler_done.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-ans-state', auto_states: ['created'])
    call = Timeout.timeout(5) { captured_q.pop }
    Timeout.timeout(5) { handler_done.pop }

    RelayMockTest.journal.push(state_push_frame('c-ans-state', 'answered'))
    deadline = Time.now + 5
    sleep 0.02 until call.state == 'answered' || Time.now > deadline

    assert_equal 'answered', call.state
  end

  # ---- Handler hangs up / passes ---------------------------------------

  def test_hangup_in_handler_journals_calling_end
    hung_q = Queue.new
    @client.on_call do |call|
      call.hangup(reason: 'busy')
      hung_q.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-hangup', auto_states: ['created'])
    Timeout.timeout(5) { hung_q.pop }
    sleep 0.1
    ends = RelayMockTest.journal.journal_recv(method: 'calling.end')

    refute_empty ends, 'no calling.end frame in journal'
    p = ends.last.frame['params']

    assert_equal 'c-hangup', p['call_id']
    assert_equal 'busy',     p['reason']
  end

  def test_pass_in_handler_journals_calling_pass
    passed_q = Queue.new
    @client.on_call do |call|
      call.pass_call
      passed_q.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-pass', auto_states: ['created'])
    Timeout.timeout(5) { passed_q.pop }
    sleep 0.1
    passes = RelayMockTest.journal.journal_recv(method: 'calling.pass')

    refute_empty passes, 'no calling.pass frame in journal'
    assert_equal 'c-pass', passes.last.frame['params']['call_id']
  end

  # ---- Multiple inbound calls ------------------------------------------

  def test_multiple_inbound_calls_in_sequence_each_unique_object
    seen_q = Queue.new
    @client.on_call do |call|
      seen_q.push(call)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-seq-1', auto_states: ['created'])
    sleep 0.1
    RelayMockTest.journal.inbound_call(call_id: 'c-seq-2', auto_states: ['created'])

    a = Timeout.timeout(5) { seen_q.pop }
    b = Timeout.timeout(5) { seen_q.pop }
    ids = [a.call_id, b.call_id].sort

    assert_equal %w[c-seq-1 c-seq-2], ids
    refute_same a, b
  end

  def test_multiple_inbound_calls_no_state_bleed
    by_id = {}
    by_id_mu = Mutex.new
    pushed = Queue.new
    @client.on_call do |call|
      by_id_mu.synchronize { by_id[call.call_id] = call }
      call.answer
      pushed.push(true)
    end

    RelayMockTest.journal.inbound_call(call_id: 'cb-1', auto_states: ['created'])
    sleep 0.05
    RelayMockTest.journal.inbound_call(call_id: 'cb-2', auto_states: ['created'])
    Timeout.timeout(5) { pushed.pop }
    Timeout.timeout(5) { pushed.pop }

    RelayMockTest.journal.push(state_push_frame('cb-1', 'answered'))
    cb1 = nil
    cb2 = nil
    deadline = Time.now + 5
    while Time.now < deadline
      by_id_mu.synchronize do
        cb1 = by_id['cb-1']
        cb2 = by_id['cb-2']
      end
      break if cb1 && cb1.state == 'answered'

      sleep 0.02
    end

    assert_equal 'answered', cb1.state
    refute_equal 'answered', cb2.state
  end

  # ---- Scripted state sequences ----------------------------------------

  def test_scripted_state_sequence_advances_call
    captured_q = Queue.new
    handler_done = Queue.new
    @client.on_call do |call|
      captured_q.push(call)
      call.answer
      handler_done.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-scripted', auto_states: ['created'])
    call = Timeout.timeout(5) { captured_q.pop }
    Timeout.timeout(5) { handler_done.pop }

    RelayMockTest.journal.push(state_push_frame('c-scripted', 'answered'))
    RelayMockTest.journal.push(state_push_frame('c-scripted', 'ended'))
    deadline = Time.now + 5
    sleep 0.02 until call.state == 'ended' || Time.now > deadline

    assert_equal 'ended', call.state
  end

  # ---- Handler patterns ------------------------------------------------

  def test_async_handler_completes_normally
    seen_q = Queue.new
    @client.on_call do |call|
      sleep 0.01
      seen_q.push(call.call_id)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-async', auto_states: ['created'])
    cid = Timeout.timeout(5) { seen_q.pop }

    assert_equal 'c-async', cid
  end

  def test_handler_exception_does_not_crash_client
    fired_q = Queue.new
    @client.on_call do |_call|
      fired_q.push(true)
      raise 'intentional from handler'
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-raise', auto_states: ['created'])
    Timeout.timeout(5) { fired_q.pop }
    sleep 0.1
    # Drive a follow-up round-trip to prove the connection survived.
    RelayMockTest.journal.inbound_call(call_id: 'c-raise-2', auto_states: ['created'])
    sleep 0.2
    sessions = RelayMockTest.journal.sessions

    assert_predicate sessions, :any?, 'WebSocket session should still be open after handler raise'
  end

  # ---- scenario_play -- full inbound flow ------------------------------

  def test_scenario_play_full_inbound_flow
    captured_q = Queue.new
    handler_started = Queue.new
    @client.on_call do |call|
      captured_q.push(call)
      call.answer
      handler_started.push(true)
    end

    timeline = [
      {
        'push' => {
          'frame' => {
            'jsonrpc' => '2.0',
            'id' => SecureRandom.uuid,
            'method' => 'signalwire.event',
            'params' => {
              'event_type' => 'calling.call.receive',
              'params' => {
                'call_id' => 'c-scen',
                'node_id' => 'mock-relay-node-1',
                'tag' => '',
                'call_state' => 'created',
                'direction' => 'inbound',
                'device' => {
                  'type' => 'phone',
                  'params' => {
                    'from_number' => '+15551110000',
                    'to_number' => '+15552220000'
                  }
                },
                'context' => 'default'
              }
            }
          }
        }
      },
      { 'expect_recv' => { 'method' => 'calling.answer', 'timeout_ms' => 5000 } },
      { 'push'        => { 'frame' => state_push_frame('c-scen', 'answered') } },
      { 'sleep_ms'    => 50 },
      { 'push'        => { 'frame' => state_push_frame('c-scen', 'ended') } }
    ]
    result = RelayMockTest.journal.scenario_play(timeline)

    assert_equal 'completed', result['status'],
                 "scenario didn't complete: #{result.inspect}"

    Timeout.timeout(5) { handler_started.pop }
    call = Timeout.timeout(5) { captured_q.pop }
    deadline = Time.now + 5
    sleep 0.02 until call.state == 'ended' || Time.now > deadline

    assert_equal 'ended', call.state
  end

  # ---- Wire shape: calling.call.receive --------------------------------

  def test_inbound_call_journal_send_records_calling_call_receive
    handler_done = Queue.new
    @client.on_call do |_call|
      handler_done.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: 'c-wire', auto_states: ['created'])
    Timeout.timeout(5) { handler_done.pop }

    sends = RelayMockTest.journal.journal_send(event_type: 'calling.call.receive')

    refute_empty sends, 'no calling.call.receive frame in journal'
    inner = sends.last.frame['params']['params']

    assert_equal 'c-wire',  inner['call_id']
    assert_equal 'inbound', inner['direction']
  end

  # ---- Inbound without a registered handler ----------------------------

  def test_inbound_without_handler_does_not_crash
    # Use a fresh client so there's no registered handler from prior tests.
    h = RelayMockTest.client
    begin
      RelayMockTest.journal.inbound_call(call_id: 'c-nohandler',
                                         auto_states: ['created'])
      sleep 0.3
      sessions = RelayMockTest.journal.sessions

      assert_predicate sessions, :any?, 'session should still be open without handler'
    ensure
      RelayMockTest.shutdown_client(h)
    end
  end
end
