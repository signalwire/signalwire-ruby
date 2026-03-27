# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/relay/constants'
require_relative '../../lib/signalwire/relay/relay_event'
require_relative '../../lib/signalwire/relay/message'

class RelayMessageDetailedTest < Minitest::Test
  def test_message_creation
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-1', context: 'default', direction: 'outbound',
      from_number: '+15551111111', to_number: '+15552222222',
      body: 'Hello', state: 'queued'
    )
    assert_equal 'msg-1', msg.message_id
    assert_equal 'outbound', msg.direction
    assert_equal 'Hello', msg.body
    assert_equal 'queued', msg.state
    refute msg.done?
  end

  def test_message_state_dispatch
    msg = SignalWire::Relay::Message.new(message_id: 'msg-2', state: 'queued')

    payload = {
      'event_type' => 'messaging.state',
      'params' => { 'message_id' => 'msg-2', 'message_state' => 'sent' }
    }
    msg._dispatch_event(payload)
    assert_equal 'sent', msg.state
    refute msg.done?

    payload = {
      'event_type' => 'messaging.state',
      'params' => { 'message_id' => 'msg-2', 'message_state' => 'delivered' }
    }
    msg._dispatch_event(payload)
    assert_equal 'delivered', msg.state
    assert msg.done?
  end

  def test_message_on_completed
    msg = SignalWire::Relay::Message.new(message_id: 'msg-4', state: 'queued')
    callback_fired = false
    msg.on_completed { callback_fired = true }

    payload = {
      'event_type' => 'messaging.state',
      'params' => { 'message_id' => 'msg-4', 'message_state' => 'failed', 'reason' => 'carrier error' }
    }
    msg._dispatch_event(payload)
    assert callback_fired
    assert_equal 'carrier error', msg.reason
  end

  def test_message_to_s
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-6', direction: 'outbound', state: 'queued',
      from_number: '+15551111111', to_number: '+15552222222'
    )
    str = msg.to_s
    assert_match(/msg-6/, str)
    assert_match(/outbound/, str)
  end

  def test_message_wait_with_timeout
    msg = SignalWire::Relay::Message.new(message_id: 'msg-3', state: 'queued')
    Thread.new do
      sleep 0.05
      payload = {
        'event_type' => 'messaging.state',
        'params' => { 'message_id' => 'msg-3', 'message_state' => 'delivered' }
      }
      msg._dispatch_event(payload)
    end
    result = msg.wait(timeout: 2)
    assert msg.done?
    assert_kind_of SignalWire::Relay::RelayEvent, result
  end
end
