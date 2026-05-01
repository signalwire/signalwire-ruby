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

class RelayEventDispatchMockTest < Minitest::Test
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

  def answered_call(call_id = 'evt-call-1')
    captured_q = Queue.new
    handler_done = Queue.new
    @client.on_call do |call|
      captured_q.push(call)
      call.answer
      handler_done.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: call_id, auto_states: ['created'])
    Timeout.timeout(5) { handler_done.pop }
    call = Timeout.timeout(5) { captured_q.pop }
    call.state = 'answered'
    call
  end

  def bare_event_frame(event_type, params)
    {
      'jsonrpc' => '2.0',
      'id'      => SecureRandom.uuid,
      'method'  => 'signalwire.event',
      'params'  => { 'event_type' => event_type, 'params' => params },
    }
  end

  # ---- Sub-command journaling ------------------------------------------

  def test_record_pause_journals_record_pause
    call = answered_call('ec-rec-pa')
    action = call.record(audio: { 'format' => 'wav' }, control_id: 'ec-rec-pa-1')
    action.pause(behavior: 'continuous')
    pauses = RelayMockTest.journal.journal_recv(method: 'calling.record.pause')
    refute_empty pauses
    p = pauses.last.frame['params']
    assert_equal 'ec-rec-pa-1', p['control_id']
    assert_equal 'continuous',  p['behavior']
  end

  def test_record_resume_journals_record_resume
    call = answered_call('ec-rec-re')
    action = call.record(audio: { 'format' => 'wav' }, control_id: 'ec-rec-re-1')
    action.resume
    resumes = RelayMockTest.journal.journal_recv(method: 'calling.record.resume')
    refute_empty resumes
    assert_equal 'ec-rec-re-1', resumes.last.frame['params']['control_id']
  end

  def test_collect_start_input_timers_journals_correctly
    call = answered_call('ec-col-sit')
    action = call.collect(
      { 'digits' => { 'max' => 4 }, 'start_input_timers' => false },
      control_id: 'ec-col-sit-1',
    )
    action.start_input_timers
    starts = RelayMockTest.journal.journal_recv(
      method: 'calling.collect.start_input_timers',
    )
    refute_empty starts
    assert_equal 'ec-col-sit-1', starts.last.frame['params']['control_id']
  end

  def test_play_volume_carries_negative_value
    call = answered_call('ec-pvol')
    action = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 60 } }],
      control_id: 'ec-pvol-1',
    )
    action.volume(-5.5)
    vol = RelayMockTest.journal.journal_recv(method: 'calling.play.volume')
    refute_empty vol
    assert_equal(-5.5, vol.last.frame['params']['volume'])
  end

  # ---- Unknown event types ---------------------------------------------

  def test_unknown_event_type_does_not_crash
    RelayMockTest.journal.push(bare_event_frame('nonsense.unknown', { 'foo' => 'bar' }))
    sleep 0.1
    assert @client._connected?, 'client should still be connected'
  end

  def test_event_with_bad_call_id_is_dropped
    RelayMockTest.journal.push(bare_event_frame(
      'calling.call.play',
      { 'call_id' => 'no-such-call-bogus', 'control_id' => 'stranger',
        'state'   => 'playing' },
    ))
    sleep 0.1
    assert @client._connected?
  end

  def test_event_with_empty_event_type_is_dropped
    RelayMockTest.journal.push(bare_event_frame('', { 'call_id' => 'x' }))
    sleep 0.1
    assert @client._connected?
  end

  # ---- Multi-action concurrency ----------------------------------------

  def test_three_concurrent_actions_resolve_independently
    call = answered_call('ec-3acts')
    play1 = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 60 } }],
      control_id: '3a-p1',
    )
    play2 = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 60 } }],
      control_id: '3a-p2',
    )
    rec = call.record(audio: { 'format' => 'wav' }, control_id: '3a-r1')

    RelayMockTest.journal.push(bare_event_frame(
      'calling.call.play',
      { 'call_id' => 'ec-3acts', 'control_id' => '3a-p1', 'state' => 'finished' },
    ))
    play1.wait(timeout: 2)
    assert play1.done?
    refute play2.done?
    refute rec.done?

    RelayMockTest.journal.push(bare_event_frame(
      'calling.call.play',
      { 'call_id' => 'ec-3acts', 'control_id' => '3a-p2', 'state' => 'finished' },
    ))
    play2.wait(timeout: 2)
    assert play2.done?
    refute rec.done?
  end

  # ---- Event ACK round-trip --------------------------------------------

  def test_event_ack_sent_back_to_server
    evt_id = 'evt-ack-test-1'
    RelayMockTest.journal.push({
      'jsonrpc' => '2.0',
      'id'      => evt_id,
      'method'  => 'signalwire.event',
      'params'  => {
        'event_type' => 'calling.call.play',
        'params'     => {
          'call_id'    => 'anything',
          'control_id' => 'x',
          'state'      => 'playing',
        },
      },
    })
    sleep 0.3

    j = RelayMockTest.journal.journal
    acks = j.select do |e|
      e.direction == 'recv' && e.frame['id'] == evt_id && e.frame.key?('result')
    end
    assert(
      !acks.empty?,
      "no event ACK with id=#{evt_id.inspect} found in journal; saw recv frames=" \
      "#{j.select { |e| e.direction == 'recv' && e.frame['id'] == evt_id }.map(&:frame).inspect}",
    )
  end

  # ---- Tag-based dial routing ------------------------------------------

  def test_dial_event_routes_via_tag_when_no_top_level_call_id
    RelayMockTest.journal.arm_dial(
      tag:            'ec-tag-route',
      winner_call_id: 'WINTAG',
      states:         %w[created answered],
      node_id:        'n',
      device:         { 'type' => 'phone', 'params' => {} },
    )
    call = @client.dial(
      [[{ 'type' => 'phone',
          'params' => { 'to_number' => '+1', 'from_number' => '+2' } }]],
      tag: 'ec-tag-route', timeout: 5,
    )
    assert_equal 'WINTAG', call.call_id
    sends = RelayMockTest.journal.journal_send(event_type: 'calling.call.dial')
    refute_empty sends, 'no calling.call.dial event in journal'
    inner = sends.last.frame['params']['params']
    refute inner.key?('call_id'),
           'top-level call_id should be absent on dial event'
    assert_equal 'WINTAG', inner['call']['call_id']
  end

  # ---- Server ping handling --------------------------------------------

  def test_server_ping_acked_by_sdk
    ping_id = 'ping-test-1'
    RelayMockTest.journal.push({
      'jsonrpc' => '2.0',
      'id'      => ping_id,
      'method'  => 'signalwire.ping',
      'params'  => {},
    })
    sleep 0.3

    j = RelayMockTest.journal.journal
    pongs = j.select do |e|
      e.direction == 'recv' && e.frame['id'] == ping_id && e.frame.key?('result')
    end
    refute_empty pongs,
                 "SDK did not respond to ping; recv frames seen with id=#{ping_id.inspect}: " \
                 "#{j.select { |e| e.direction == 'recv' && e.frame['id'] == ping_id }.map(&:frame).inspect}"
  end

  # ---- Authorization state ---------------------------------------------

  def test_authorization_state_event_captured
    RelayMockTest.journal.push(bare_event_frame(
      'signalwire.authorization.state',
      { 'authorization_state' => 'test-auth-state-blob' },
    ))
    deadline = Time.now + 5
    until @client._authorization_state || Time.now > deadline
      sleep 0.02
    end
    assert_equal 'test-auth-state-blob', @client._authorization_state
  end

  # ---- calling.error event ---------------------------------------------

  def test_calling_error_event_does_not_crash
    RelayMockTest.journal.push(bare_event_frame(
      'calling.error',
      { 'code' => '5001', 'message' => 'synthetic error' },
    ))
    sleep 0.1
    assert @client._connected?
  end

  # ---- State event for an answered call --------------------------------

  def test_call_state_event_updates_state
    call = answered_call('ec-stt')
    RelayMockTest.journal.push(bare_event_frame(
      'calling.call.state',
      { 'call_id' => 'ec-stt', 'call_state' => 'ending', 'direction' => 'inbound' },
    ))
    deadline = Time.now + 5
    until call.state == 'ending' || Time.now > deadline
      sleep 0.02
    end
    assert_equal 'ending', call.state
  end

  def test_call_listener_fires_on_event
    call = answered_call('ec-list')
    fired_q = Queue.new
    call.on('calling.call.play') do |event|
      fired_q.push(event)
    end
    RelayMockTest.journal.push(bare_event_frame(
      'calling.call.play',
      { 'call_id' => 'ec-list', 'control_id' => 'x', 'state' => 'playing' },
    ))
    event = Timeout.timeout(2) { fired_q.pop }
    assert_equal 'calling.call.play', event.event_type
  end
end
