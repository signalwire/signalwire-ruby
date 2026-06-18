# frozen_string_literal: true

# Real-mock-backed tests for messaging (send_message + inbound).
#
# Translated from
# signalwire-python/tests/unit/relay/test_messaging_mock.py.

require 'minitest/autorun'
require 'securerandom'
require 'timeout'
require_relative 'mock_test'

# Shared fixture + send/event/assert helpers for the messaging mock tests.
module RelayMessagingHelpers
  def setup
    RelayMockTest.reset
    @handle = RelayMockTest.client
    @client = @handle[:client]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
    RelayMockTest.reset
  end

  # Send a message with the standard test numbers; +body+ defaults to 'hi'.
  def send_basic_message(body: 'hi', **extra)
    @client.send_message(to_number: '+15551112222', from_number: '+15553334444',
                         body: body, **extra)
  end

  # The single messaging.send frame's params (asserts exactly one was sent).
  def sole_send_params
    sends = RelayMockTest.journal.journal_recv(method: 'messaging.send')

    assert_equal 1, sends.size
    sends[0].frame['params']
  end

  # Push a signalwire.event frame with the given event_type + inner params.
  def push_event(event_type, params)
    RelayMockTest.journal.push({
                                 'jsonrpc' => '2.0',
                                 'id' => SecureRandom.uuid,
                                 'method' => 'signalwire.event',
                                 'params' => { 'event_type' => event_type, 'params' => params }
                               })
  end

  def push_message_state(message_id, state, extra: {})
    params = { 'message_id' => message_id, 'message_state' => state }.merge(extra)
    push_event('messaging.state', params)
  end

  # Spin (briefly) until the message reaches +state+ or a 2s deadline passes.
  def wait_for_state(msg, state)
    deadline = Time.now + 2
    sleep 0.02 until msg.state == state || Time.now > deadline
  end

  def inbound_message_params
    {
      'message_id' => 'in-msg-1', 'context' => 'default', 'direction' => 'inbound',
      'from_number' => '+15551110000', 'to_number' => '+15552220000',
      'body' => 'hello back', 'media' => [], 'segments' => 1,
      'message_state' => 'received', 'tags' => ['incoming']
    }
  end
end

class RelayMessagingMockTest < Minitest::Test
  include RelayMessagingHelpers

  # ---- send_message: outbound -------------------------------------------

  def test_send_message_journals_messaging_send
    msg = send_basic_message(body: 'hello', tags: %w[t1 t2])

    assert_kind_of SignalWire::Relay::Message, msg
    refute_empty msg.message_id, 'mock should generate a message_id'
    assert_equal 'hello', msg.body

    p = sole_send_params

    assert_equal '+15551112222', p['to_number']
    assert_equal '+15553334444', p['from_number']
    assert_equal 'hello',         p['body']
    assert_equal %w[t1 t2],       p['tags']
  end

  def test_send_message_with_media_only
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      media: ['https://media.example/cat.jpg']
    )

    assert_kind_of SignalWire::Relay::Message, msg
    p = sole_send_params

    assert_equal ['https://media.example/cat.jpg'], p['media']
    body = p['body']

    assert(body.nil? || body.empty?, "expected no body, got #{body.inspect}")
  end

  def test_send_message_includes_context
    send_basic_message(context: 'custom-ctx')

    assert_equal 'custom-ctx', sole_send_params['context']
  end

  def test_send_message_returns_initial_state_queued
    msg = send_basic_message

    assert_equal 'queued', msg.state
    refute_predicate msg, :done?
  end

  # ---- send_message: terminal state events resolve message.wait ---------

  def test_send_message_resolves_on_delivered
    msg = send_basic_message
    push_message_state(msg.message_id, 'delivered',
                       extra: { 'from_number' => '+15553334444',
                                'to_number' => '+15551112222',
                                'body' => 'hi' })
    event = msg.wait(timeout: 5)

    assert_equal 'delivered', msg.state
    assert_predicate msg, :done?
    assert_equal 'delivered', event.params['message_state']
  end

  def test_send_message_resolves_on_undelivered
    msg = send_basic_message
    push_message_state(msg.message_id, 'undelivered', extra: { 'reason' => 'carrier_blocked' })
    msg.wait(timeout: 5)

    assert_equal 'undelivered', msg.state
    assert_equal 'carrier_blocked', msg.reason
  end

  def test_send_message_resolves_on_failed
    msg = send_basic_message
    push_message_state(msg.message_id, 'failed', extra: { 'reason' => 'spam' })
    msg.wait(timeout: 5)

    assert_equal 'failed', msg.state
  end

  def test_send_message_intermediate_state_does_not_resolve
    msg = send_basic_message
    push_message_state(msg.message_id, 'sent')
    wait_for_state(msg, 'sent')

    assert_equal 'sent', msg.state
    refute_predicate msg, :done?, 'sent is intermediate, message should not be done'
  end
end

# Inbound delivery + full state progression. Split from the outbound-send
# tests to keep each class within budget.
class RelayMessagingInboundMockTest < Minitest::Test
  include RelayMessagingHelpers

  # ---- Inbound messages -------------------------------------------------

  def test_inbound_message_fires_on_message_handler
    received_q = Queue.new
    @client.on_message { |m| received_q.push(m) }
    push_event('messaging.receive', inbound_message_params)
    Timeout.timeout(5) { @inbound = received_q.pop }

    assert_inbound_message(@inbound)
  end

  def assert_inbound_message(inbound)
    assert_equal 'in-msg-1',     inbound.message_id
    assert_equal 'inbound',      inbound.direction
    assert_equal '+15551110000', inbound.from_number
    assert_equal '+15552220000', inbound.to_number
    assert_equal 'hello back',   inbound.body
    assert_equal ['incoming'],   inbound.tags
  end

  # ---- Full state progression -------------------------------------------

  def test_full_message_state_progression
    msg = send_basic_message(body: 'full pipeline')
    push_message_state(msg.message_id, 'sent')
    wait_for_state(msg, 'sent')

    assert_equal 'sent', msg.state

    push_message_state(msg.message_id, 'delivered')
    msg.wait(timeout: 5)

    assert_equal 'delivered', msg.state
  end
end
