# frozen_string_literal: true

# Real-mock-backed tests for SDK event dispatch / routing.
#
# Translated from
# signalwire-python/tests/unit/relay/test_event_dispatch_mock.py.
#
# Focus: edge cases in the SDK's recv loop and event router that don't
# fit neatly into per-action / per-call test files.

require 'minitest/autorun'
require 'securerandom'
require 'timeout'
require_relative 'mock_test'

# Shared mock lifecycle + frame helpers for the event-dispatch test classes.
module RelayEventDispatchSupport
  # Parallelize: per-client session scoping isolates each test's journal/pushes.
  def self.included(base)
    base.parallelize_me!
  end

  def setup
    # No global reset: the per-client @mock is scoped to this connection's
    # session id and starts with an empty (scoped) journal, so the shared mock
    # is safe under parallel execution.
    @handle = RelayMockTest.client
    @client = @handle[:client]
    @mock   = @handle[:mock]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
  end

  def answered_call(call_id = 'evt-call-1')
    captured_q = Queue.new
    handler_done = Queue.new
    @client.on_call(nil) { |call| _answer_and_signal(call, captured_q, handler_done) }
    @mock.inbound_call(call_id: call_id, auto_states: ['created'])
    Timeout.timeout(5) { handler_done.pop }
    call = Timeout.timeout(5) { captured_q.pop }
    call.state = 'answered'
    call
  end

  def _answer_and_signal(call, captured_q, handler_done)
    captured_q.push(call)
    call.answer
    handler_done.push(true)
  end

  def bare_event_frame(event_type, params, id: SecureRandom.uuid)
    {
      'jsonrpc' => '2.0',
      'id' => id,
      'method' => 'signalwire.event',
      'params' => { 'event_type' => event_type, 'params' => params }
    }
  end

  # Push a calling.call.play "finished" event for the given call/control id.
  def push_play_finished(call_id, control_id)
    @mock.push(bare_event_frame(
                 'calling.call.play',
                 { 'call_id' => call_id, 'control_id' => control_id, 'state' => 'finished' }
               ))
  end

  # Start a 60s silence playback on +call+ under the given control id.
  def play_silence(call, control_id)
    call.play([{ 'type' => 'silence', 'params' => { 'duration' => 60 } }], control_id: control_id)
  end

  # Journaled 'recv' frames carrying the given id that include a 'result'
  # (i.e. ACK/PONG responses the SDK sent back).
  def recv_results_for(frame_id)
    @mock.journal.select do |e|
      e.direction == 'recv' && e.frame['id'] == frame_id && e.frame.key?('result')
    end
  end

  # All 'recv' frames carrying the given id (for diagnostics).
  def recv_frames_for(frame_id)
    @mock.journal
         .select { |e| e.direction == 'recv' && e.frame['id'] == frame_id }
         .map(&:frame)
  end
end

class RelayEventDispatchMockTest < Minitest::Test
  include RelayEventDispatchSupport

  # ---- Sub-command journaling ------------------------------------------

  def test_record_pause_journals_record_pause
    call = answered_call('ec-rec-pa')
    action = call.record(audio: { 'format' => 'wav' }, control_id: 'ec-rec-pa-1')
    action.pause(behavior: 'continuous')
    pauses = @mock.journal_recv(method: 'calling.record.pause')

    refute_empty pauses
    p = pauses.last.frame['params']

    assert_equal 'ec-rec-pa-1', p['control_id']
    assert_equal 'continuous',  p['behavior']
  end

  def test_record_resume_journals_record_resume
    call = answered_call('ec-rec-re')
    action = call.record(audio: { 'format' => 'wav' }, control_id: 'ec-rec-re-1')
    action.resume
    resumes = @mock.journal_recv(method: 'calling.record.resume')

    refute_empty resumes
    assert_equal 'ec-rec-re-1', resumes.last.frame['params']['control_id']
  end

  def test_collect_start_input_timers_journals_correctly
    call = answered_call('ec-col-sit')
    digits = { 'digits' => { 'max' => 4 }, 'start_input_timers' => false }
    call.collect(digits, control_id: 'ec-col-sit-1').start_input_timers
    starts = @mock.journal_recv(method: 'calling.collect.start_input_timers')

    refute_empty starts
    assert_equal 'ec-col-sit-1', starts.last.frame['params']['control_id']
  end

  def test_play_volume_carries_negative_value
    call = answered_call('ec-pvol')
    action = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 60 } }],
      control_id: 'ec-pvol-1'
    )
    action.volume(-5.5)
    vol = @mock.journal_recv(method: 'calling.play.volume')

    refute_empty vol
    assert_in_delta(-5.5, vol.last.frame['params']['volume'])
  end

  # ---- Unknown event types ---------------------------------------------

  def test_unknown_event_type_does_not_crash
    @mock.push(bare_event_frame('nonsense.unknown', { 'foo' => 'bar' }))
    sleep 0.1

    assert_predicate @client, :_connected?, 'client should still be connected'
  end

  def test_event_with_bad_call_id_is_dropped
    @mock.push(bare_event_frame(
                 'calling.call.play',
                 { 'call_id' => 'no-such-call-bogus', 'control_id' => 'stranger',
                   'state' => 'playing' }
               ))
    sleep 0.1

    assert_predicate @client, :_connected?
  end

  def test_event_with_empty_event_type_is_dropped
    @mock.push(bare_event_frame('', { 'call_id' => 'x' }))
    sleep 0.1

    assert_predicate @client, :_connected?
  end
end

# Multi-action concurrency, event ACKs, and tag-based dial routing.
class RelayEventDispatchConcurrencyMockTest < Minitest::Test
  include RelayEventDispatchSupport

  def test_three_concurrent_actions_resolve_independently
    call = answered_call('ec-3acts')
    play1 = play_silence(call, '3a-p1')
    play2 = play_silence(call, '3a-p2')
    rec = call.record(audio: { 'format' => 'wav' }, control_id: '3a-r1')

    finish_play(play1, 'ec-3acts', '3a-p1')

    assert_done_only(play1, pending: [play2, rec])

    finish_play(play2, 'ec-3acts', '3a-p2')

    assert_done_only(play2, pending: [rec])
  end

  # Assert +action+ has resolved while every action in +pending+ has not.
  def assert_done_only(action, pending:)
    assert_predicate action, :done?
    pending.each { |a| refute_predicate a, :done? }
  end

  # Push the play-finished event for +control_id+ and wait for +action+.
  def finish_play(action, call_id, control_id)
    push_play_finished(call_id, control_id)
    action.wait(timeout: 2)
  end

  # ---- Event ACK round-trip --------------------------------------------

  def test_event_ack_sent_back_to_server
    evt_id = 'evt-ack-test-1'
    params = { 'call_id' => 'anything', 'control_id' => 'x', 'state' => 'playing' }
    @mock.push(bare_event_frame('calling.call.play', params, id: evt_id))
    sleep 0.3

    refute_empty(
      recv_results_for(evt_id),
      "no event ACK with id=#{evt_id.inspect} found in journal; " \
      "saw recv frames=#{recv_frames_for(evt_id).inspect}"
    )
  end

  # ---- Tag-based dial routing ------------------------------------------

  def test_dial_event_routes_via_tag_when_no_top_level_call_id
    arm_tag_dial('ec-tag-route', 'WINTAG')
    device = { 'type' => 'phone', 'params' => { 'to_number' => '+1', 'from_number' => '+2' } }
    call = @client.dial([[device]], tag: 'ec-tag-route', dial_timeout: 5)

    assert_equal 'WINTAG', call.call_id
    sends = @mock.journal_send(event_type: 'calling.call.dial')

    refute_empty sends, 'no calling.call.dial event in journal'
    inner = sends.last.frame['params']['params']

    refute inner.key?('call_id'), 'top-level call_id should be absent on dial event'
    assert_equal 'WINTAG', inner['call']['call_id']
  end

  def arm_tag_dial(tag, winner_call_id)
    @mock.arm_dial(
      tag: tag, winner_call_id: winner_call_id, states: %w[created answered],
      node_id: 'n', device: { 'type' => 'phone', 'params' => {} }
    )
  end
end

# Server ping handling, state-event capture, and call listeners.
class RelayEventDispatchStateMockTest < Minitest::Test
  include RelayEventDispatchSupport

  def test_server_ping_acked_by_sdk
    ping_id = 'ping-test-1'
    @mock.push(
      { 'jsonrpc' => '2.0', 'id' => ping_id, 'method' => 'signalwire.ping', 'params' => {} }
    )
    sleep 0.3

    refute_empty recv_results_for(ping_id),
                 "SDK did not respond to ping; recv frames seen with id=#{ping_id.inspect}: " \
                 "#{recv_frames_for(ping_id).inspect}"
  end

  # ---- Authorization state ---------------------------------------------

  def test_authorization_state_event_captured
    @mock.push(bare_event_frame(
                 'signalwire.authorization.state',
                 { 'authorization_state' => 'test-auth-state-blob' }
               ))
    deadline = Time.now + 5
    sleep 0.02 until @client._authorization_state || Time.now > deadline

    assert_equal 'test-auth-state-blob', @client._authorization_state
  end

  # ---- calling.error event ---------------------------------------------

  def test_calling_error_event_does_not_crash
    @mock.push(bare_event_frame(
                 'calling.error',
                 { 'code' => '5001', 'message' => 'synthetic error' }
               ))
    sleep 0.1

    assert_predicate @client, :_connected?
  end

  # ---- State event for an answered call --------------------------------

  def test_call_state_event_updates_state
    call = answered_call('ec-stt')
    @mock.push(bare_event_frame(
                 'calling.call.state',
                 { 'call_id' => 'ec-stt', 'call_state' => 'ending', 'direction' => 'inbound' }
               ))
    deadline = Time.now + 5
    sleep 0.02 until call.state == 'ending' || Time.now > deadline

    assert_equal 'ending', call.state
  end

  def test_call_listener_fires_on_event
    call = answered_call('ec-list')
    fired_q = Queue.new
    call.on('calling.call.play', nil) { |event| fired_q.push(event) }
    params = { 'call_id' => 'ec-list', 'control_id' => 'x', 'state' => 'playing' }
    @mock.push(bare_event_frame('calling.call.play', params))
    event = Timeout.timeout(2) { fired_q.pop }

    assert_equal 'calling.call.play', event.event_type
  end
end
