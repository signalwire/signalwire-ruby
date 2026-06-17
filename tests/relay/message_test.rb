# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
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
    refute_predicate msg, :done?
  end

  def test_message_state_dispatch
    msg = SignalWire::Relay::Message.new(message_id: 'msg-2', state: 'queued')

    payload = {
      'event_type' => 'messaging.state',
      'params' => { 'message_id' => 'msg-2', 'message_state' => 'sent' }
    }
    msg._dispatch_event(payload)

    assert_equal 'sent', msg.state
    refute_predicate msg, :done?

    payload = {
      'event_type' => 'messaging.state',
      'params' => { 'message_id' => 'msg-2', 'message_state' => 'delivered' }
    }
    msg._dispatch_event(payload)

    assert_equal 'delivered', msg.state
    assert_predicate msg, :done?
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

    assert_predicate msg, :done?
    assert_kind_of SignalWire::Relay::RelayEvent, result
  end

  # ---- Tier-2 idiom layer: pattern matching / to_h / value equality ----

  def sample_message(message_id: 'msg-9', state: 'queued')
    SignalWire::Relay::Message.new(
      message_id: message_id, context: 'default', direction: 'outbound',
      from_number: '+15551111111', to_number: '+15552222222',
      body: 'Hello', media: ['https://example.com/a.jpg'], segments: 1,
      state: state, tags: %w[alpha]
    )
  end

  def test_message_hash_pattern_match
    msg = sample_message

    matched =
      case msg
      in { direction: 'outbound', body:, from_number: }
        [body, from_number]
      else
        :no_match
      end

    assert_equal ['Hello', '+15551111111'], matched
  end

  def test_message_deconstruct_keys_subset
    subset = sample_message.deconstruct_keys(%i[message_id state])

    assert_equal({ message_id: 'msg-9', state: 'queued' }, subset)
    refute subset.key?(:body), 'subset must not include unrequested keys'
  end

  def test_message_array_pattern_match
    destructured =
      case sample_message(message_id: 'msg-arr', state: 'sent')
      in [id, direction, state]
        [id, direction, state]
      end

    assert_equal %w[msg-arr outbound sent], destructured
  end

  def test_message_to_h_excludes_completion_machinery
    h = sample_message.to_h

    assert_equal 'msg-9', h[:message_id]
    assert_equal 'Hello', h[:body]
    assert_equal ['https://example.com/a.jpg'], h[:media]
    assert_equal %w[alpha], h[:tags]
    refute h.key?(:mutex), 'to_h must expose only value fields, not sync state'
    refute h.key?(:done)
  end

  def test_message_to_json_round_trip
    parsed = JSON.parse(sample_message.to_json)

    assert_equal 'msg-9', parsed['message_id']
    assert_equal 'outbound', parsed['direction']
    assert_equal 'Hello', parsed['body']
  end

  def test_messages_with_same_data_are_value_equal
    m1 = sample_message
    m2 = sample_message

    assert_equal m1, m2
    assert m1.eql?(m2)
    assert_equal m1.hash, m2.hash
  end

  def test_messages_with_different_data_differ
    refute_equal sample_message(message_id: 'a'), sample_message(message_id: 'b')
  end

  def test_equal_messages_dedupe_in_set_and_key_hash
    m1 = sample_message
    m2 = sample_message
    m3 = sample_message(message_id: 'distinct')

    set = Set.new([m1, m2, m3])

    assert_equal 2, set.size

    table = { m1 => 'delivered' }

    assert_equal 'delivered', table[m2]
  end
end
