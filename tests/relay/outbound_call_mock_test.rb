# frozen_string_literal: true

# Real-mock-backed tests for outbound calls (RelayClient.dial).
#
# Translated from
# signalwire-python/tests/unit/relay/test_outbound_call_mock.py.
#
# The dial flow is the most fragile RELAY surface: calling.dial returns a
# plain 200 with NO call_id; the actual call info arrives via subsequent
# calling.call.state (per leg) and calling.call.dial (with the winner)
# events keyed by tag.

require 'minitest/autorun'
require 'securerandom'
require 'timeout'
require_relative 'mock_test'

# Shared fixture + dial/journal helpers for the outbound-call (dial) tests.
module RelayOutboundCallHelpers
  # Parallelize: per-client session scoping isolates each test's dial scenarios.
  def self.included(base)
    base.parallelize_me!
  end

  def setup
    @handle = RelayMockTest.client
    @client = @handle[:client]
    @mock   = @handle[:mock]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
  end

  def phone_device(to: '+15551112222', frm: '+15553334444')
    { 'type' => 'phone', 'params' => { 'to_number' => to, 'from_number' => frm } }
  end

  # Arm the mock's scripted dial for +tag+ -> +winner+ and return the Call.
  # +arm:+ extra arm_dial kwargs (states/losers/delay_ms/...); +dial:+ extra
  # dial kwargs (max_duration/...); +devices:+ the device matrix to dial.
  def arm_and_dial(tag:, winner:, states: %w[created answered], arm: {}, dial: {}, devices: nil)
    @mock.arm_dial(tag: tag, winner_call_id: winner, states: states,
                   node_id: 'node-mock-1', device: phone_device, **arm)
    @client.dial(devices || [[phone_device]], tag: tag, timeout: 5, **dial)
  end

  # The single calling.dial frame's params (asserts exactly one was sent).
  def sole_dial_params
    dials = @mock.journal_recv(method: 'calling.dial')

    assert_equal 1, dials.size
    dials[0].frame['params']
  end

  # A calling.call.dial signalwire.event frame for tag -> dial_state + call.
  def call_dial_event(tag, dial_state, call)
    {
      'jsonrpc' => '2.0', 'id' => SecureRandom.uuid, 'method' => 'signalwire.event',
      'params' => {
        'event_type' => 'calling.call.dial',
        'params' => { 'tag' => tag, 'node_id' => 'node-mock-1',
                      'dial_state' => dial_state, 'call' => call }
      }
    }
  end
end

class RelayOutboundCallMockTest < Minitest::Test
  include RelayOutboundCallHelpers

  UUID_RE = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

  # ---- Happy-path dial -------------------------------------------------

  def test_dial_resolves_to_call_with_winner_id
    call = arm_and_dial(tag: 't-happy', winner: 'winner-1',
                        states: %w[created ringing answered], arm: { delay_ms: 1 })

    assert_kind_of SignalWire::Relay::Call, call
    assert_equal 'winner-1', call.call_id
    assert_equal 't-happy',  call.tag
    assert_equal 'answered', call.state
    assert_equal 'outbound', call.direction
  end

  def test_dial_journal_records_calling_dial_frame
    arm_and_dial(tag: 't-frame', winner: 'winner-frame')
    p = sole_dial_params

    assert_equal 't-frame', p['tag']
    assert_kind_of Array, p['devices']
    assert_equal 'phone', p['devices'][0][0]['type']
  end

  def test_dial_with_max_duration_in_frame
    arm_and_dial(tag: 't-md', winner: 'winner-md', dial: { max_duration: 300 })

    assert_equal 300, sole_dial_params['max_duration']
  end

  def test_dial_auto_generates_uuid_tag_when_omitted
    seen_tag = Queue.new
    pusher = Thread.new { push_winner_for_pending_dial(seen_tag) }

    call = @client.dial([[phone_device]], timeout: 5)
    pusher.join(5)
    tag = seen_tag.pop

    assert_equal 'auto-tag-winner', call.call_id
    assert_match(UUID_RE, tag, "expected UUID-shaped tag, got #{tag.inspect}")
    assert_equal tag, call.tag
  end

  # Wait for the calling.dial frame, push +seen_tag+ its auto-generated tag,
  # then push an answered winner event back keyed on that tag.
  def push_winner_for_pending_dial(seen_tag)
    tag = wait_for_dial_tag
    seen_tag.push(tag)
    return unless tag

    winner = { 'call_id' => 'auto-tag-winner', 'node_id' => 'node-mock-1', 'tag' => tag,
               'device' => phone_device, 'dial_winner' => true }
    @mock.push(call_dial_event(tag, 'answered', winner))
  end

  # Poll for the calling.dial frame; return its tag (or nil after ~2s).
  def wait_for_dial_tag
    40.times do
      entries = @mock.journal_recv(method: 'calling.dial')
      return entries.last.frame['params']['tag'] unless entries.empty?

      sleep 0.05
    end
    nil
  end

  # ---- Failure paths ---------------------------------------------------

  def test_dial_failed_raises_relay_error
    pusher = Thread.new do
      wait_for_dial_tag
      @mock.push(call_dial_event('t-fail', 'failed', {}))
    end
    err = assert_raises(SignalWire::Relay::RelayError) do
      @client.dial([[phone_device]], tag: 't-fail', timeout: 5)
    end
    pusher.join(5)

    assert_match(/Dial failed/i, err.message)
  end

  def test_dial_timeout_when_no_dial_event
    err = assert_raises(SignalWire::Relay::ActionTimeoutError) do
      @client.dial([[phone_device]], tag: 't-timeout', timeout: 0.5)
    end
    assert_match(/timed out/i, err.message)
  end
end

# Parallel-dial (winner/losers), wire-shape, state-progression, post-dial, and
# envelope tests. Split from the happy-path/failure tests to keep each class
# within budget.
class RelayOutboundCallWireMockTest < Minitest::Test
  include RelayOutboundCallHelpers

  # ---- Parallel dial -- winner + losers --------------------------------

  def test_dial_winner_carries_dial_winner_true
    call = arm_and_dial(
      tag: 't-winner', winner: 'WIN-ID',
      arm: { losers: [{ 'call_id' => 'LOSE-A', 'states' => %w[created ended] },
                      { 'call_id' => 'LOSE-B', 'states' => %w[created ended] }] }
    )

    assert_equal 'WIN-ID', call.call_id
    inner = sole_answered_dial_event

    assert inner['call']['dial_winner']
    assert_equal 'WIN-ID', inner['call']['call_id']
  end

  # The single answered calling.call.dial event's inner params.
  def sole_answered_dial_event
    sends = @mock.journal_send(event_type: 'calling.call.dial')

    refute_empty sends, 'no calling.call.dial event was pushed'
    finals = sends.select do |e|
      ((e.frame['params'] || {})['params'] || {})['dial_state'] == 'answered'
    end

    assert_equal 1, finals.size
    finals[0].frame['params']['params']
  end

  def test_dial_losers_cleaned_up_from_calls_dict
    call = arm_and_dial(tag: 't-cleanup', winner: 'WIN-CL',
                        arm: { losers: [{ 'call_id' => 'LOSE-CL', 'states' => %w[created ended] }] })
    sleep 0.1 # Allow loser ended event to flow
    snap = @client._calls_snapshot

    refute snap.key?('LOSE-CL'), 'ended loser should be removed from registry'
    assert snap.key?(call.call_id), 'winner should remain in registry'
  end

  def test_dial_losers_get_state_events
    arm_and_dial(tag: 't-losers', winner: 'WIN-2',
                 arm: { losers: [{ 'call_id' => 'L1', 'states' => %w[created ended] }] })
    loser_states = sent_call_states('L1')

    assert(loser_states.any? { |p| p['call_state'] == 'ended' },
           "loser L1 never reached 'ended'; saw: #{loser_states.inspect}")
  end

  # The pushed calling.call.state events' inner params for +call_id+.
  def sent_call_states(call_id)
    @mock.journal_send(event_type: 'calling.call.state')
         .map { |e| e.frame['params']['params'] }
         .select { |p| p['call_id'] == call_id }
  end

  # ---- Devices shape on the wire ---------------------------------------

  def test_dial_devices_serial_two_legs_on_wire
    devs = [[phone_device(to: '+15551110001'), phone_device(to: '+15551110002')]]
    arm_and_dial(tag: 't-serial', winner: 'WIN-SER', devices: devs)
    legs = sole_dial_params['devices']

    assert_equal 1, legs.size
    assert_equal 2, legs[0].size
    assert_equal '+15551110001', legs[0][0]['params']['to_number']
  end

  def test_dial_devices_parallel_two_legs_on_wire
    devs = [[phone_device(to: '+15551110001')], [phone_device(to: '+15551110002')]]
    arm_and_dial(tag: 't-par', winner: 'WIN-PAR', devices: devs)

    assert_equal 2, sole_dial_params['devices'].size
  end

  # ---- State transitions during dial -----------------------------------

  def test_dial_records_call_state_progression_on_winner
    call = arm_and_dial(tag: 't-prog', winner: 'WIN-PROG', states: %w[created ringing answered])
    winner_states = sent_call_states('WIN-PROG').map { |p| p['call_state'] }

    assert_includes winner_states, 'created'
    assert_includes winner_states, 'ringing'
    assert_includes winner_states, 'answered'
    assert_equal 'answered', call.state
  end

  # ---- After dial -- call object is usable -----------------------------

  def test_dialed_call_can_send_subsequent_command
    call = arm_and_dial(tag: 't-after', winner: 'WIN-AFTER')
    call.hangup
    end_frames = @mock.journal_recv(method: 'calling.end')

    refute_empty end_frames, 'no calling.end frame in journal'
    assert_equal 'WIN-AFTER', end_frames.last.frame['params']['call_id']
  end

  def test_dialed_call_can_play
    call = arm_and_dial(tag: 't-play', winner: 'WIN-PLAY')
    call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hi' } }])
    play_frames = @mock.journal_recv(method: 'calling.play')

    refute_empty play_frames, 'no calling.play frame after dial'
    p = play_frames.last.frame['params']

    assert_equal 'WIN-PLAY', p['call_id']
    assert_equal 'tts',      p['play'][0]['type']
  end

  # ---- Tag preservation ------------------------------------------------

  def test_dial_preserves_explicit_tag
    call = arm_and_dial(tag: 'my-very-explicit-tag-99', winner: 'WIN-T')

    assert_equal 'my-very-explicit-tag-99', call.tag
  end

  # ---- JSON-RPC envelope -----------------------------------------------

  def test_dial_frame_uses_jsonrpc_envelope
    arm_and_dial(tag: 't-rpc', winner: 'W')
    dials = @mock.journal_recv(method: 'calling.dial')

    assert_equal 1, dials.size
    f = dials[0].frame

    assert_equal '2.0',          f['jsonrpc']
    assert_equal 'calling.dial', f['method']
    assert f.key?('id')
    assert f.key?('params')
  end
end
