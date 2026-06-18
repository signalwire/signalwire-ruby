# frozen_string_literal: true

# Tier-3 typed-object coverage (SELECTIVE, highest-traffic relay blobs):
#
#   * Device         -- the { type, params } descriptor for connect/refer/
#                       dial/tap. Typed SHAPE, type stays a String.
#   * CollectConfig  -- the known-shape collect config the input wrappers
#                       enumerate.
#   * RELAY state enums -- CallState / DialState / MessageState frozen named
#                       constants + terminal? predicate + a typed accessor
#                       alongside the bare string.
#
# Every assertion drives REAL behavior -- no transport mocks. The Device /
# CollectConfig wire-shape tests dial a call through the shared porting-sdk
# mock_relay server and read back the actual JSON-RPC frame the SDK sent, then
# assert it is byte identical to the hand-written Hash. The state tests parse
# real signalwire.event payloads (and run a real message dispatch) and assert
# the typed predicate agrees with the bare string.
#
# Additive contract: the raw-Hash path stays. These tests prove a Device /
# CollectConfig built object yields the IDENTICAL wire frame as the literal the
# existing convenience_mock_test / outbound_call_mock_test assert on.

require 'minitest/autorun'
require 'json'
require 'securerandom'
require_relative 'mock_test'

# Shared setup/teardown + dial/journal helpers for the Tier-3 typed-object
# test classes (Device, CollectConfig, state enums), split out so no single
# Minitest class grows unbounded.
module RelayTier3Helpers
  R = SignalWire::Relay

  # Parallelize: per-client session scoping isolates each test's dial journals.
  def self.included(base)
    base.parallelize_me!
  end

  def setup
    # No global reset: @mock is scoped to this client's session and starts
    # empty, keeping the shared mock parallel-safe.
    @handle = RelayMockTest.client
    @client = @handle[:client]
    @mock   = @handle[:mock]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
  end

  # The hand-written phone device literal the existing suite uses verbatim.
  def phone_device_hash(to: '+15551112222', frm: '+15553334444')
    { 'type' => 'phone', 'params' => { 'to_number' => to, 'from_number' => frm } }
  end

  def dial_call(tag:, call_id:, devices:, states: %w[created answered])
    @mock.arm_dial(tag: tag, winner_call_id: call_id, states: states,
                   node_id: 'node-mock-1', device: phone_device_hash)
    call = @client.dial(devices, tag: tag, timeout: 5)

    assert_kind_of R::Call, call
    assert_equal call_id, call.call_id
    call
  end

  def last_params(method)
    frames = @mock.journal_recv(method: method)

    refute_empty frames, "no #{method} frame in journal"
    frames.last.frame['params']
  end
end

# ======================================================================
# 1. Device
# ======================================================================
class RelayTier3DeviceTest < Minitest::Test
  include RelayTier3Helpers

  R = SignalWire::Relay

  # Pure: Device.to_h is byte identical to the hand-written Hash the rest of
  # the suite passes raw.
  def test_device_to_h_byte_identical_to_hand_written_hash
    hand = phone_device_hash
    dev  = R::Device.phone(to: '+15551112222', from: '+15553334444')

    assert_equal hand, dev.to_h
    # Byte-level: same serialized JSON, same key order.
    assert_equal JSON.generate(hand), JSON.generate(dev.to_h)
  end

  def test_device_to_h_stringifies_symbol_params
    dev = R::Device.new(:phone, to_number: '+15551110000')

    assert_equal({ 'type' => 'phone', 'params' => { 'to_number' => '+15551110000' } },
                 dev.to_h)
  end

  def test_device_omits_unset_optionals
    dev = R::Device.phone(to: '+15551112222') # no from, no timeout

    assert_equal({ 'type' => 'phone', 'params' => { 'to_number' => '+15551112222' } },
                 dev.to_h)
    refute dev.to_h['params'].key?('from_number')
    refute dev.to_h['params'].key?('timeout')
  end

  def test_device_sip_shape
    dev = R::Device.sip(to: 'sip:bob@example.com', headers: { 'X-Foo' => 'bar' })
    expected = { 'type' => 'sip',
                 'params' => { 'to' => 'sip:bob@example.com', 'headers' => { 'X-Foo' => 'bar' } } }

    assert_equal(expected, dev.to_h)
  end

  # Real round-trip: a Device built object drives a real dial and lands the
  # IDENTICAL devices frame as the hand-written literal does in
  # outbound_call_mock_test#test_dial_journal_records_calling_dial_frame.
  def test_device_round_trips_through_real_dial
    dev = R::Device.phone(to: '+15551112222', from: '+15553334444')
    dial_call(tag: 't-dev', call_id: 'WIN-DEV', devices: [[dev.to_h]])

    p = last_params('calling.dial')

    assert_equal 't-dev', p['tag']
    assert_single_phone_device(p['devices'])
  end

  def assert_single_phone_device(devices)
    assert_equal 1, devices.size
    assert_equal 1, devices[0].size
    on_wire = devices[0][0]
    # The frame the SDK emitted is byte identical to the hand-written literal.
    assert_equal phone_device_hash, on_wire
    assert_equal 'phone', on_wire['type']
    assert_equal '+15551112222', on_wire['params']['to_number']
  end

  # Real round-trip through a real connect: Device.to_h lands verbatim inside
  # the calling.connect `devices` list-of-lists.
  def test_device_round_trips_through_real_connect
    call = dial_call(tag: 't-conn', call_id: 'WIN-CONN', devices: [[phone_device_hash]])
    dev = R::Device.phone(to: '+15557778888', from: '+15559990000')
    call.connect(devices: [[dev.to_h]])

    p = last_params('calling.connect')

    assert_equal 'WIN-CONN', p['call_id']
    on_wire = p['devices'][0][0]

    assert_equal dev.to_h, on_wire
    assert_equal '+15557778888', on_wire['params']['to_number']
  end

  # A raw-Hash device and the equivalent Device produce the SAME wire frame:
  # proves the typed path is purely additive over the raw path.
  def test_device_and_raw_hash_produce_identical_dial_frame
    # Raw-hash dial.
    dial_call(tag: 't-raw', call_id: 'W-RAW', devices: [[phone_device_hash]])
    raw_frame = last_params('calling.dial')['devices']

    @mock.reset
    # Typed-Device dial (same data).
    dev = R::Device.phone(to: '+15551112222', from: '+15553334444')
    dial_call(tag: 't-typed', call_id: 'W-TYP', devices: [[dev.to_h]])
    typed_frame = last_params('calling.dial')['devices']

    assert_equal raw_frame, typed_frame,
                 'typed Device must serialize identically to the raw Hash'
  end

  # ---- Device value-object idioms (consistent with Wave-A relay events) --

  def test_device_value_equality_and_hash
    a = R::Device.phone(to: '+1', from: '+2')
    b = R::Device.phone(to: '+1', from: '+2')
    c = R::Device.phone(to: '+9', from: '+2')

    assert_equal a, b
    assert a.eql?(b)
    assert_equal a.hash, b.hash
    refute_equal a, c
  end

  def test_device_dedupes_in_a_set
    a = R::Device.phone(to: '+1')
    b = R::Device.phone(to: '+1')
    c = R::Device.phone(to: '+2')
    set = Set.new([a, b, c])

    assert_equal 2, set.size
  end

  def test_device_hash_pattern_match
    dev = R::Device.phone(to: '+15551112222')
    bound =
      case dev
      in { type: 'phone', params: }
        params['to_number']
      else
        :no_match
      end

    assert_equal '+15551112222', bound
  end

  def test_device_array_pattern_match
    dev = R::Device.new('sip', { 'to' => 'sip:x@y' })
    t, params =
      case dev
      in [type, p]
        [type, p]
      end

    assert_equal 'sip', t
    assert_equal({ 'to' => 'sip:x@y' }, params)
  end
end

# ======================================================================
# 2. CollectConfig
# ======================================================================
class RelayTier3CollectConfigTest < Minitest::Test
  include RelayTier3Helpers

  R = SignalWire::Relay

  def test_collect_config_to_h_digits_shape
    cfg = R::CollectConfig.new(digits: { max: 4, terminators: '#' },
                               initial_timeout: 5.0)

    assert_equal({ 'digits' => { 'max' => 4, 'terminators' => '#' },
                   'initial_timeout' => 5.0 }, cfg.to_h)
  end

  def test_collect_config_omits_unset_sections
    cfg = R::CollectConfig.new(digits: { max: 1 })

    assert_equal({ 'digits' => { 'max' => 1 } }, cfg.to_h)
    refute cfg.to_h.key?('speech')
    refute cfg.to_h.key?('initial_timeout')
  end

  def test_collect_config_speech_shape
    cfg = R::CollectConfig.new(speech: { 'end_silence_timeout' => 1.0, 'language' => 'en-US' })

    assert_equal({ 'speech' => { 'end_silence_timeout' => 1.0, 'language' => 'en-US' } },
                 cfg.to_h)
  end

  def test_collect_config_passes_through_boolean_toggles
    cfg = R::CollectConfig.new(digits: { max: 2 }, partial_results: false,
                               continuous: true)
    h = cfg.to_h
    # Booleans pass through even when false (omit-when-nil, not omit-when-falsey):
    # the keys are PRESENT (omit-when-nil would drop them) and carry the bools.
    assert h.key?('partial_results')
    assert h.key?('continuous')
    refute h['partial_results']
    assert h['continuous']
  end

  # Real round-trip: CollectConfig.to_h matches the wrapper's wire shape. The
  # convenience_mock_test asserts prompt_tts passes the *collect* object
  # through verbatim; here we hand prompt_tts a CollectConfig.to_h and assert
  # the SAME journal shape.
  def test_collect_config_matches_wrapper_wire_shape_via_play_and_collect
    cfg = R::CollectConfig.new(digits: { 'max' => 4 }, initial_timeout: 5.0)
    call = dial_call(tag: 't-cc', call_id: 'C-CC', devices: [[phone_device_hash]])
    call.prompt_tts('enter your pin', cfg.to_h, language: 'en-US', volume: 3.0)

    p = last_params('calling.play_and_collect')

    assert_equal 'C-CC', p['call_id']
    assert_play_and_collect_shape(p, cfg)
  end

  def assert_play_and_collect_shape(params, cfg)
    collect = params['collect']
    # collect object on the wire equals the typed config's to_h, verbatim.
    assert_equal cfg.to_h, collect
    assert_equal 4, collect['digits']['max']
    assert_in_delta(5.0, collect['initial_timeout'])
    # media + volume still ride correctly alongside.
    assert_equal 'tts', params['play'][0]['type']
    assert_in_delta(3.0, params['volume'])
  end

  # A raw collect Hash and the equivalent CollectConfig produce the SAME
  # collect frame on a real standalone collect call.
  def test_collect_config_and_raw_hash_produce_identical_collect_frame
    raw = { 'digits' => { 'max' => 4 }, 'initial_timeout' => 5.0 }
    cfg = R::CollectConfig.new(digits: { max: 4 }, initial_timeout: 5.0)
    call = dial_call(tag: 't-cc2', call_id: 'C-CC2', devices: [[phone_device_hash]])

    raw_collect = collect_and_capture(call, raw, 'ctl-raw')
    typed_collect = collect_and_capture(call, cfg.to_h, 'ctl-typed')

    # Compare the collect-config slice (control_id differs by design).
    %w[digits initial_timeout].each do |k|
      assert_equal raw_collect[k], typed_collect[k],
                   "collect field #{k} must match between raw and typed"
    end
  end

  # Issue a standalone collect and return the params of the resulting frame.
  def collect_and_capture(call, collect_arg, control_id)
    call.collect(collect_arg, control_id: control_id)
    last_params('calling.collect')
  end

  def test_collect_config_value_equality_and_pattern_match
    a = R::CollectConfig.new(digits: { max: 4 }, initial_timeout: 5.0)
    b = R::CollectConfig.new(digits: { max: 4 }, initial_timeout: 5.0)

    assert_equal a, b
    assert_equal a.hash, b.hash

    bound =
      case a
      in { initial_timeout: }
        initial_timeout
      end

    assert_in_delta(5.0, bound)
  end
end

# ======================================================================
# 3. RELAY state enums
# ======================================================================
class RelayTier3StateEnumsTest < Minitest::Test
  include RelayTier3Helpers

  R = SignalWire::Relay

  # ---- CallState -------------------------------------------------------

  def test_call_state_all_and_terminal_set
    assert_equal %w[created ringing answered ending ended], R::CallState::ALL
    assert_predicate R::CallState::ALL, :frozen?
    assert_equal %w[ended], R::CallState::TERMINAL
    assert_predicate R::CallState::TERMINAL, :frozen?
  end

  def test_call_state_terminal_predicate
    assert R::CallState.terminal?('ended')
    refute R::CallState.terminal?('answered')
    refute R::CallState.terminal?('ringing')
    refute R::CallState.terminal?(nil)
  end

  def test_call_state_constants_match_flat_literals
    assert_equal R::CALL_STATE_ENDED,    R::CallState::ENDED
    assert_equal R::CALL_STATE_ANSWERED, R::CallState::ANSWERED
  end

  # Typed accessor agrees with the bare string, over a REAL dispatched event.
  # We dial a call, drive it to `ended` via a real state event, and assert the
  # CallStateEvent#terminal? typed accessor agrees with the string call_state.
  def test_call_state_event_terminal_accessor_agrees_over_real_event
    call = dial_call(tag: 't-cs', call_id: 'C-CS', devices: [[phone_device_hash]])

    captured = []
    call.on(R::EVENT_CALL_STATE) { |e| captured << e }
    # Dispatch a real ended state event (same path RelayClient uses).
    call._dispatch_event('event_type' => 'calling.call.state',
                         'params' => { 'call_id' => 'C-CS', 'call_state' => 'ended' })

    refute_empty captured, 'no calling.call.state event dispatched'
    ended_ev = captured.find { |e| e.call_state == 'ended' }

    refute_nil ended_ev
    # Typed predicate agrees with the bare string read.
    assert_equal R::CallState.terminal?(ended_ev.call_state), ended_ev.terminal?
    assert_predicate ended_ev, :terminal?, 'ended must be terminal'
  end

  def test_call_state_event_non_terminal_accessor_over_real_event
    ev = R.parse_event(
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'x', 'call_state' => 'ringing' }
    )

    assert_equal 'ringing', ev.call_state # string still there
    refute_predicate ev, :terminal?
    assert_equal R::CallState.terminal?(ev.call_state), ev.terminal?
  end

  # ---- DialState -------------------------------------------------------

  def test_dial_state_all_and_terminal_set
    assert_equal %w[dialing answered failed], R::DialState::ALL
    assert_predicate R::DialState::ALL, :frozen?
    assert_equal %w[answered failed], R::DialState::TERMINAL
    assert_predicate R::DialState::TERMINAL, :frozen?
  end

  def test_dial_state_terminal_predicate
    assert R::DialState.terminal?('answered')
    assert R::DialState.terminal?('failed')
    refute R::DialState.terminal?('dialing')
  end

  # Typed accessors agree with the bare string over a real dial event that the
  # outbound dial flow actually dispatches.
  def test_dial_event_typed_accessors_agree_over_real_event
    answered_params = { 'tag' => 't', 'dial_state' => 'answered', 'call' => { 'call_id' => 'w' } }
    ev = R.parse_event('event_type' => 'calling.call.dial', 'params' => answered_params)

    assert_equal 'answered', ev.dial_state # string preserved
    assert_predicate ev, :answered?
    refute_predicate ev, :failed?
    assert_predicate ev, :terminal?
    assert_equal R::DialState.terminal?(ev.dial_state), ev.terminal?

    assert_failed_dial_event
  end

  def assert_failed_dial_event
    failed_params = { 'tag' => 't', 'dial_state' => 'failed', 'call' => {} }
    failed = R.parse_event('event_type' => 'calling.call.dial', 'params' => failed_params)

    assert_predicate failed, :failed?
    assert_predicate failed, :terminal?
    refute_predicate failed, :answered?
  end

  # End-to-end: a real outbound dial that the mock resolves to `answered`
  # leaves a calling.call.dial frame whose dial_state the typed DialState
  # classifies as terminal.
  def test_dial_state_terminal_over_real_dispatched_dial_event
    dial_call(tag: 't-ds', call_id: 'WIN-DS', devices: [[phone_device_hash]])
    sends = @mock.journal_send(event_type: 'calling.call.dial')

    refute_empty sends, 'mock did not push a calling.call.dial event'
    final = sends.map { |e| (e.frame['params'] || {})['params'] }
                 .find { |pp| pp && pp['dial_state'] == 'answered' }

    refute_nil final, 'no answered dial_state in the pushed events'
    assert R::DialState.terminal?(final['dial_state'])
  end
end

# ---- MessageState ----------------------------------------------------
class RelayTier3MessageStateTest < Minitest::Test
  include RelayTier3Helpers

  R = SignalWire::Relay

  def test_message_state_all_and_terminal_set
    assert_equal %w[queued initiated sent delivered undelivered failed received],
                 R::MessageState::ALL
    assert_predicate R::MessageState::ALL, :frozen?
    assert_equal %w[delivered undelivered failed], R::MessageState::TERMINAL
    # TERMINAL is the same object as the flat constant (single source).
    assert_equal R::MESSAGE_TERMINAL_STATES, R::MessageState::TERMINAL
  end

  def test_message_state_terminal_predicate
    assert R::MessageState.terminal?('delivered')
    assert R::MessageState.terminal?('undelivered')
    assert R::MessageState.terminal?('failed')
    refute R::MessageState.terminal?('queued')
    refute R::MessageState.terminal?('sent')
  end

  # Typed accessor agrees with the bare string over a REAL message dispatch:
  # a Message that processes a real messaging.state event reaches terminal?,
  # and the value agrees with MessageState.terminal?(state).
  def test_message_terminal_accessor_agrees_over_real_dispatch
    msg = R::Message.new(message_id: 'm1', state: 'sent')

    refute_predicate msg, :terminal?
    assert_equal R::MessageState.terminal?(msg.state), msg.terminal?

    # Drive a real delivered event through the actual dispatch path.
    msg._dispatch_event('event_type' => 'messaging.state',
                        'params' => { 'message_id' => 'm1', 'message_state' => 'delivered' })

    assert_equal 'delivered', msg.state # string updated
    assert_predicate msg, :terminal?, 'delivered message must be terminal'
    assert_equal R::MessageState.terminal?(msg.state), msg.terminal?
    assert_predicate msg, :done?, 'terminal message must have resolved its wait'
  end

  def test_message_state_event_terminal_accessor_over_real_event
    ev = R.parse_event(
      'event_type' => 'messaging.state',
      'params' => { 'message_id' => 'm2', 'message_state' => 'failed' }
    )

    assert_equal 'failed', ev.message_state
    assert_predicate ev, :terminal?
    assert_equal R::MessageState.terminal?(ev.message_state), ev.terminal?
  end

  # ---- 3-vocabulary trap: the three enums never conflate ---------------

  def test_state_vocabularies_are_distinct
    # `answered` is a call state AND a dial state, but NOT a message state.
    assert R::CallState.valid?('answered')
    assert R::DialState.valid?('answered')
    refute R::MessageState.valid?('answered')

    # `delivered` is a message state only.
    assert R::MessageState.valid?('delivered')
    refute R::CallState.valid?('delivered')
    refute R::DialState.valid?('delivered')

    # `dialing` is a dial state only.
    assert R::DialState.valid?('dialing')
    refute R::CallState.valid?('dialing')

    # Terminal sets differ: call's terminal {ended} != dial's {answered,failed}.
    refute_equal R::CallState::TERMINAL, R::DialState::TERMINAL
  end
end
