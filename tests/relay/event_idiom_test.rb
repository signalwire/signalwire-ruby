# frozen_string_literal: true

# Tier-2 idiom coverage for the relay Event classes: Ruby 3.0 pattern
# matching (deconstruct_keys / deconstruct), the to_h / to_json projection
# layer, and value-based ==/eql?/hash so events work as Set members and
# Hash keys.
#
# Every test drives a *real* event parsed from a real signalwire.event
# wire payload — no mocks, no stubbed transport. Assertions are
# content-shaped: they fail if the projected data is wrong.

require 'minitest/autorun'
require 'json'
require 'set'
require_relative '../../lib/signalwire/relay/constants'
require_relative '../../lib/signalwire/relay/relay_event'

class RelayEventIdiomTest < Minitest::Test
  R = SignalWire::Relay

  # A real calling.call.state frame as the mock RELAY server emits it.
  def state_payload(call_id: 'abc-123')
    {
      'event_type' => 'calling.call.state',
      'params' => {
        'call_id'    => call_id,
        'timestamp'  => 100.5,
        'call_state' => 'answered',
        'direction'  => 'inbound',
        'end_reason' => '',
        'device'     => { 'type' => 'phone', 'params' => { 'number' => '+15551112222' } }
      }
    }
  end

  # ---- Pattern matching (the headline feature) -------------------------

  def test_hash_pattern_match_binds_typed_fields
    event = R.parse_event(state_payload)

    matched =
      case event
      in { event_type: 'calling.call.state', call_state:, direction: }
        [call_state, direction]
      else
        :no_match
      end

    assert_equal %w[answered inbound], matched
  end

  def test_hash_pattern_guard_on_event_type_rejects_mismatch
    play = R.parse_event(
      'event_type' => 'calling.call.play',
      'params' => { 'call_id' => 'c1', 'control_id' => 'ctl-1', 'state' => 'finished' }
    )

    branch =
      case play
      in { event_type: 'calling.call.state' }
        :state_branch
      in { event_type: 'calling.call.play', state: }
        "play:#{state}"
      end

    assert_equal 'play:finished', branch
  end

  def test_deconstruct_keys_full_matches_to_h
    event = R.parse_event(state_payload)
    # nil keys => full map, which must equal the to_h projection.
    assert_equal event.to_h, event.deconstruct_keys(nil)
  end

  def test_deconstruct_keys_subset_returns_only_requested
    event = R.parse_event(state_payload)
    subset = event.deconstruct_keys(%i[call_id call_state])

    assert_equal({ call_id: 'abc-123', call_state: 'answered' }, subset)
    refute subset.key?(:direction), 'subset must not include unrequested keys'
  end

  def test_array_pattern_match_destructures_envelope
    event = R.parse_event(state_payload)

    destructured =
      case event
      in [event_type, call_id, timestamp]
        [event_type, call_id, timestamp]
      end

    assert_equal ['calling.call.state', 'abc-123', 100.5], destructured
  end

  def test_base_relay_event_pattern_matches_envelope
    base = R::RelayEvent.from_payload(
      'event_type' => 'some.unmapped.event',
      'params' => { 'call_id' => 'base-1', 'timestamp' => 7.0 }
    )

    matched =
      case base
      in { event_type:, call_id: }
        [event_type, call_id]
      end

    assert_equal ['some.unmapped.event', 'base-1'], matched
  end

  # ---- to_h / to_json round-trip ---------------------------------------

  def test_to_h_includes_envelope_and_typed_fields
    h = R.parse_event(state_payload).to_h

    assert_equal 'calling.call.state', h[:event_type]
    assert_equal 'abc-123', h[:call_id]
    assert_equal 100.5, h[:timestamp]
    assert_equal 'answered', h[:call_state]
    assert_equal 'inbound', h[:direction]
    assert_equal({ 'type' => 'phone', 'params' => { 'number' => '+15551112222' } }, h[:device])
  end

  def test_to_h_omits_raw_params_frame
    h = R.parse_event(state_payload).to_h
    refute h.key?(:params), 'to_h is the typed projection, not the raw wire frame'
  end

  def test_to_json_round_trips_through_parse
    event = R.parse_event(state_payload)
    parsed = JSON.parse(event.to_json)

    assert_equal 'calling.call.state', parsed['event_type']
    assert_equal 'abc-123', parsed['call_id']
    assert_equal 'answered', parsed['call_state']
    # Nested hashes survive serialization.
    assert_equal 'phone', parsed['device']['type']
  end

  def test_record_event_to_h_exposes_nested_record_fields
    event = R.parse_event(
      'event_type' => 'calling.call.record',
      'params' => {
        'call_id' => 'c1', 'control_id' => 'ctl-2', 'state' => 'finished',
        'record' => { 'url' => 'https://example.com/rec.mp3', 'duration' => 30.5, 'size' => 102_400 }
      }
    )
    h = event.to_h

    assert_equal 'https://example.com/rec.mp3', h[:url]
    assert_equal 30.5, h[:duration]
    assert_equal 102_400, h[:size]
  end

  # ---- Value equality / hash / Set / Hash key --------------------------

  def test_two_events_from_same_payload_are_value_equal
    e1 = R.parse_event(state_payload)
    e2 = R.parse_event(state_payload)

    assert_equal e1, e2
    assert e1.eql?(e2), 'eql? must agree with =='
    assert_equal e1.hash, e2.hash, 'equal events must hash equal'
  end

  def test_events_with_different_data_are_not_equal
    e1 = R.parse_event(state_payload(call_id: 'abc-123'))
    e2 = R.parse_event(state_payload(call_id: 'zzz-999'))

    refute_equal e1, e2
    refute_equal e1.hash, e2.hash
  end

  def test_same_envelope_different_class_are_not_equal
    state = R.parse_event(state_payload)
    play  = R.parse_event(
      'event_type' => 'calling.call.play',
      'params' => { 'call_id' => 'abc-123', 'timestamp' => 100.5 }
    )

    refute_equal state, play, 'a CallStateEvent and a PlayEvent must never compare equal'
  end

  def test_equal_events_collapse_in_a_set
    e1 = R.parse_event(state_payload)
    e2 = R.parse_event(state_payload)
    e3 = R.parse_event(state_payload(call_id: 'other'))

    set = Set.new([e1, e2, e3])

    assert_equal 2, set.size, 'value-equal events must dedupe; the distinct one stays'
    assert set.include?(e1)
    assert set.include?(e3)
  end

  def test_event_usable_as_hash_key_via_value_equality
    e1 = R.parse_event(state_payload)
    e2 = R.parse_event(state_payload)
    table = { e1 => 'handled' }

    # A *different* instance carrying the same data resolves the same key.
    assert_equal 'handled', table[e2]
  end
end
