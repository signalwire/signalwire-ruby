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

class RelayOutboundCallMockTest < Minitest::Test
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

  def phone_device(to: '+15551112222', frm: '+15553334444')
    { 'type' => 'phone', 'params' => { 'to_number' => to, 'from_number' => frm } }
  end

  # ---- Happy-path dial -------------------------------------------------

  def test_dial_resolves_to_call_with_winner_id
    RelayMockTest.journal.arm_dial(
      tag:            't-happy',
      winner_call_id: 'winner-1',
      states:         %w[created ringing answered],
      node_id:        'node-mock-1',
      device:         phone_device,
      delay_ms:       1,
    )
    call = @client.dial([[phone_device]], tag: 't-happy', timeout: 5)
    assert_kind_of SignalWire::Relay::Call, call
    assert_equal 'winner-1', call.call_id
    assert_equal 't-happy',  call.tag
    assert_equal 'answered', call.state
    assert_equal 'outbound', call.direction
  end

  def test_dial_journal_records_calling_dial_frame
    RelayMockTest.journal.arm_dial(
      tag:            't-frame',
      winner_call_id: 'winner-frame',
      states:         %w[created answered],
      node_id:        'node-mock-1',
      device:         phone_device,
    )
    @client.dial([[phone_device]], tag: 't-frame', timeout: 5)
    dials = RelayMockTest.journal.journal_recv(method: 'calling.dial')
    assert_equal 1, dials.size
    p = dials[0].frame['params']
    assert_equal 't-frame', p['tag']
    assert_kind_of Array, p['devices']
    assert_equal 'phone', p['devices'][0][0]['type']
  end

  def test_dial_with_max_duration_in_frame
    RelayMockTest.journal.arm_dial(
      tag: 't-md', winner_call_id: 'winner-md',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
    )
    @client.dial([[phone_device]], tag: 't-md', max_duration: 300, timeout: 5)
    dials = RelayMockTest.journal.journal_recv(method: 'calling.dial')
    assert_equal 1, dials.size
    assert_equal 300, dials[0].frame['params']['max_duration']
  end

  def test_dial_auto_generates_uuid_tag_when_omitted
    seen_tag = Queue.new
    pusher = Thread.new do
      # Wait for the calling.dial frame to land, snag the tag, push the
      # answered event back.
      tag = nil
      40.times do
        entries = RelayMockTest.journal.journal_recv(method: 'calling.dial')
        unless entries.empty?
          tag = entries.last.frame['params']['tag']
          break
        end
        sleep 0.05
      end
      seen_tag.push(tag)
      next unless tag

      RelayMockTest.journal.push({
        'jsonrpc' => '2.0',
        'id'      => SecureRandom.uuid,
        'method'  => 'signalwire.event',
        'params'  => {
          'event_type' => 'calling.call.dial',
          'params'     => {
            'tag'        => tag,
            'node_id'    => 'node-mock-1',
            'dial_state' => 'answered',
            'call'       => {
              'call_id'      => 'auto-tag-winner',
              'node_id'      => 'node-mock-1',
              'tag'          => tag,
              'device'       => phone_device,
              'dial_winner'  => true,
            },
          },
        },
      })
    end

    call = @client.dial([[phone_device]], timeout: 5)
    pusher.join(5)
    tag = seen_tag.pop

    assert_equal 'auto-tag-winner', call.call_id
    assert_match(
      /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/,
      tag, "expected UUID-shaped tag, got #{tag.inspect}"
    )
    assert_equal tag, call.tag
  end

  # ---- Failure paths ---------------------------------------------------

  def test_dial_failed_raises_relay_error
    pusher = Thread.new do
      40.times do
        if RelayMockTest.journal.journal_recv(method: 'calling.dial').any?
          break
        end
        sleep 0.05
      end
      RelayMockTest.journal.push({
        'jsonrpc' => '2.0',
        'id'      => SecureRandom.uuid,
        'method'  => 'signalwire.event',
        'params'  => {
          'event_type' => 'calling.call.dial',
          'params'     => {
            'tag'        => 't-fail',
            'node_id'    => 'node-mock-1',
            'dial_state' => 'failed',
            'call'       => {},
          },
        },
      })
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

  # ---- Parallel dial -- winner + losers --------------------------------

  def test_dial_winner_carries_dial_winner_true
    RelayMockTest.journal.arm_dial(
      tag: 't-winner', winner_call_id: 'WIN-ID',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
      losers: [
        { 'call_id' => 'LOSE-A', 'states' => %w[created ended] },
        { 'call_id' => 'LOSE-B', 'states' => %w[created ended] },
      ],
    )
    call = @client.dial([[phone_device]], tag: 't-winner', timeout: 5)
    assert_equal 'WIN-ID', call.call_id

    sends = RelayMockTest.journal.journal_send(event_type: 'calling.call.dial')
    refute_empty sends, 'no calling.call.dial event was pushed'
    finals = sends.select do |e|
      ((e.frame['params'] || {})['params'] || {})['dial_state'] == 'answered'
    end
    assert_equal 1, finals.size
    inner = finals[0].frame['params']['params']
    assert_equal true,     inner['call']['dial_winner']
    assert_equal 'WIN-ID', inner['call']['call_id']
  end

  def test_dial_losers_cleaned_up_from_calls_dict
    RelayMockTest.journal.arm_dial(
      tag: 't-cleanup', winner_call_id: 'WIN-CL',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
      losers: [{ 'call_id' => 'LOSE-CL', 'states' => %w[created ended] }],
    )
    call = @client.dial([[phone_device]], tag: 't-cleanup', timeout: 5)
    sleep 0.1 # Allow loser ended event to flow
    snap = @client._calls_snapshot
    refute snap.key?('LOSE-CL'), 'ended loser should be removed from registry'
    assert snap.key?(call.call_id), 'winner should remain in registry'
  end

  def test_dial_losers_get_state_events
    RelayMockTest.journal.arm_dial(
      tag: 't-losers', winner_call_id: 'WIN-2',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
      losers: [{ 'call_id' => 'L1', 'states' => %w[created ended] }],
    )
    @client.dial([[phone_device]], tag: 't-losers', timeout: 5)
    state_events = RelayMockTest.journal.journal_send(event_type: 'calling.call.state')
    loser_states = state_events
      .map { |e| e.frame['params']['params'] }
      .select { |p| p['call_id'] == 'L1' }
    assert(
      loser_states.any? { |p| p['call_state'] == 'ended' },
      "loser L1 never reached 'ended'; saw: #{loser_states.inspect}"
    )
  end

  # ---- Devices shape on the wire ---------------------------------------

  def test_dial_devices_serial_two_legs_on_wire
    RelayMockTest.journal.arm_dial(
      tag: 't-serial', winner_call_id: 'WIN-SER',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
    )
    devs = [[phone_device(to: '+15551110001'), phone_device(to: '+15551110002')]]
    @client.dial(devs, tag: 't-serial', timeout: 5)
    dials = RelayMockTest.journal.journal_recv(method: 'calling.dial')
    assert_equal 1, dials.size
    p = dials[0].frame['params']
    assert_equal 1, p['devices'].size
    assert_equal 2, p['devices'][0].size
    assert_equal '+15551110001',
                 p['devices'][0][0]['params']['to_number']
  end

  def test_dial_devices_parallel_two_legs_on_wire
    RelayMockTest.journal.arm_dial(
      tag: 't-par', winner_call_id: 'WIN-PAR',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
    )
    devs = [
      [phone_device(to: '+15551110001')],
      [phone_device(to: '+15551110002')],
    ]
    @client.dial(devs, tag: 't-par', timeout: 5)
    dials = RelayMockTest.journal.journal_recv(method: 'calling.dial')
    assert_equal 1, dials.size
    assert_equal 2, dials[0].frame['params']['devices'].size
  end

  # ---- State transitions during dial -----------------------------------

  def test_dial_records_call_state_progression_on_winner
    RelayMockTest.journal.arm_dial(
      tag: 't-prog', winner_call_id: 'WIN-PROG',
      states: %w[created ringing answered], node_id: 'node-mock-1',
      device: phone_device,
    )
    call = @client.dial([[phone_device]], tag: 't-prog', timeout: 5)
    state_events = RelayMockTest.journal.journal_send(event_type: 'calling.call.state')
    winner_states = state_events
      .map { |e| e.frame['params']['params'] }
      .select { |p| p['call_id'] == 'WIN-PROG' }
      .map { |p| p['call_state'] }
    assert_includes winner_states, 'created'
    assert_includes winner_states, 'ringing'
    assert_includes winner_states, 'answered'
    assert_equal 'answered', call.state
  end

  # ---- After dial -- call object is usable -----------------------------

  def test_dialed_call_can_send_subsequent_command
    RelayMockTest.journal.arm_dial(
      tag: 't-after', winner_call_id: 'WIN-AFTER',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
    )
    call = @client.dial([[phone_device]], tag: 't-after', timeout: 5)
    call.hangup
    end_frames = RelayMockTest.journal.journal_recv(method: 'calling.end')
    refute_empty end_frames, 'no calling.end frame in journal'
    assert_equal 'WIN-AFTER', end_frames.last.frame['params']['call_id']
  end

  def test_dialed_call_can_play
    RelayMockTest.journal.arm_dial(
      tag: 't-play', winner_call_id: 'WIN-PLAY',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
    )
    call = @client.dial([[phone_device]], tag: 't-play', timeout: 5)
    call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hi' } }])
    play_frames = RelayMockTest.journal.journal_recv(method: 'calling.play')
    refute_empty play_frames, 'no calling.play frame after dial'
    p = play_frames.last.frame['params']
    assert_equal 'WIN-PLAY', p['call_id']
    assert_equal 'tts',      p['play'][0]['type']
  end

  # ---- Tag preservation ------------------------------------------------

  def test_dial_preserves_explicit_tag
    RelayMockTest.journal.arm_dial(
      tag: 'my-very-explicit-tag-99', winner_call_id: 'WIN-T',
      states: %w[created answered], node_id: 'node-mock-1',
      device: phone_device,
    )
    call = @client.dial([[phone_device]],
                        tag: 'my-very-explicit-tag-99', timeout: 5)
    assert_equal 'my-very-explicit-tag-99', call.tag
  end

  # ---- JSON-RPC envelope -----------------------------------------------

  def test_dial_uses_jsonrpc_2_0
    RelayMockTest.journal.arm_dial(
      tag: 't-rpc', winner_call_id: 'W',
      states: %w[created answered], node_id: 'n',
      device: phone_device,
    )
    @client.dial([[phone_device]], tag: 't-rpc', timeout: 5)
    dials = RelayMockTest.journal.journal_recv(method: 'calling.dial')
    assert_equal 1, dials.size
    f = dials[0].frame
    assert_equal '2.0',          f['jsonrpc']
    assert_equal 'calling.dial', f['method']
    assert f.key?('id')
    assert f.key?('params')
  end
end
