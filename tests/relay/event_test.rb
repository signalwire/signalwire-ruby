# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/relay/constants'
require_relative '../../lib/signalwire/relay/relay_event'

class RelayEventDetailedTest < Minitest::Test
  def test_base_event_from_payload
    payload = {
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'abc-123', 'timestamp' => 1234567.89 }
    }
    event = SignalWire::Relay::RelayEvent.from_payload(payload)
    assert_equal 'calling.call.state', event.event_type
    assert_equal 'abc-123', event.call_id
    assert_equal 1234567.89, event.timestamp
  end

  def test_call_state_event
    payload = {
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'c1', 'call_state' => 'answered', 'direction' => 'inbound' }
    }
    event = SignalWire::Relay::CallStateEvent.from_payload(payload)
    assert_instance_of SignalWire::Relay::CallStateEvent, event
    assert_equal 'answered', event.call_state
    assert_equal 'inbound', event.direction
  end

  def test_play_event
    payload = {
      'event_type' => 'calling.call.play',
      'params' => { 'call_id' => 'c1', 'control_id' => 'ctl-1', 'state' => 'finished' }
    }
    event = SignalWire::Relay::PlayEvent.from_payload(payload)
    assert_equal 'ctl-1', event.control_id
    assert_equal 'finished', event.state
  end

  def test_record_event_with_nested_record
    payload = {
      'event_type' => 'calling.call.record',
      'params' => {
        'call_id' => 'c1', 'control_id' => 'ctl-2', 'state' => 'finished',
        'record' => { 'url' => 'https://example.com/rec.mp3', 'duration' => 30.5, 'size' => 102400 }
      }
    }
    event = SignalWire::Relay::RecordEvent.from_payload(payload)
    assert_equal 'https://example.com/rec.mp3', event.url
    assert_equal 30.5, event.duration
    assert_equal 102400, event.size
  end

  def test_parse_event_routing
    payload = {
      'event_type' => 'calling.call.play',
      'params' => { 'control_id' => 'x', 'state' => 'playing' }
    }
    event = SignalWire::Relay.parse_event(payload)
    assert_instance_of SignalWire::Relay::PlayEvent, event

    payload = { 'event_type' => 'unknown.event', 'params' => {} }
    event = SignalWire::Relay.parse_event(payload)
    assert_instance_of SignalWire::Relay::RelayEvent, event
  end

  def test_event_class_map_completeness
    map = SignalWire::Relay::EVENT_CLASS_MAP
    assert_equal 23, map.size
  end

  def test_conference_event
    payload = {
      'event_type' => 'calling.conference',
      'params' => { 'conference_id' => 'conf-1', 'name' => 'standup', 'status' => 'active' }
    }
    event = SignalWire::Relay::ConferenceEvent.from_payload(payload)
    assert_equal 'conf-1', event.conference_id
    assert_equal 'standup', event.name
  end

  def test_message_receive_event
    payload = {
      'event_type' => 'messaging.receive',
      'params' => {
        'message_id' => 'msg-1', 'from_number' => '+15551234567',
        'to_number' => '+15559876543', 'body' => 'Hello'
      }
    }
    event = SignalWire::Relay::MessageReceiveEvent.from_payload(payload)
    assert_equal 'msg-1', event.message_id
    assert_equal 'Hello', event.body
  end
end
