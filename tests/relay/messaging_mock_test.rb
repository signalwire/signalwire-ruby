# frozen_string_literal: true

# Real-mock-backed tests for messaging (send_message + inbound).
#
# Translated from
# signalwire-python/tests/unit/relay/test_messaging_mock.py.

require 'minitest/autorun'
require 'securerandom'
require 'timeout'
require_relative 'mock_test'

class RelayMessagingMockTest < Minitest::Test
  def setup
    RelayMockTest.reset
    @handle = RelayMockTest.client
    @client = @handle[:client]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
    RelayMockTest.reset
  end

  # ---- send_message: outbound -------------------------------------------

  def test_send_message_journals_messaging_send
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'hello',
      tags: %w[t1 t2]
    )

    assert_kind_of SignalWire::Relay::Message, msg
    refute_empty msg.message_id, 'mock should generate a message_id'
    assert_equal 'hello', msg.body

    sends = RelayMockTest.journal.journal_recv(method: 'messaging.send')

    assert_equal 1, sends.size
    p = sends[0].frame['params']

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

    sends = RelayMockTest.journal.journal_recv(method: 'messaging.send')

    assert_equal 1, sends.size
    p = sends[0].frame['params']

    assert_equal ['https://media.example/cat.jpg'], p['media']
    body = p['body']

    assert(body.nil? || body.empty?, "expected no body, got #{body.inspect}")
  end

  def test_send_message_includes_context
    @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'hi',
      context: 'custom-ctx'
    )
    sends = RelayMockTest.journal.journal_recv(method: 'messaging.send')

    assert_equal 1, sends.size
    assert_equal 'custom-ctx', sends[0].frame['params']['context']
  end

  def test_send_message_returns_initial_state_queued
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'hi'
    )

    assert_equal 'queued', msg.state
    refute_predicate msg, :done?
  end

  # ---- send_message: terminal state events resolve message.wait ---------

  def test_send_message_resolves_on_delivered
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'hi'
    )
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
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'hi'
    )
    push_message_state(msg.message_id, 'undelivered',
                       extra: { 'reason' => 'carrier_blocked' })
    msg.wait(timeout: 5)

    assert_equal 'undelivered', msg.state
    assert_equal 'carrier_blocked', msg.reason
  end

  def test_send_message_resolves_on_failed
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'hi'
    )
    push_message_state(msg.message_id, 'failed',
                       extra: { 'reason' => 'spam' })
    msg.wait(timeout: 5)

    assert_equal 'failed', msg.state
  end

  def test_send_message_intermediate_state_does_not_resolve
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'hi'
    )
    push_message_state(msg.message_id, 'sent')
    deadline = Time.now + 2
    sleep 0.02 until msg.state == 'sent' || Time.now > deadline

    assert_equal 'sent', msg.state
    refute_predicate msg, :done?, 'sent is intermediate, message should not be done'
  end

  # ---- Inbound messages -------------------------------------------------

  def test_inbound_message_fires_on_message_handler
    received_q = Queue.new
    @client.on_message do |m|
      received_q.push(m)
    end

    RelayMockTest.journal.push({
                                 'jsonrpc' => '2.0',
                                 'id' => SecureRandom.uuid,
                                 'method' => 'signalwire.event',
                                 'params' => {
                                   'event_type' => 'messaging.receive',
                                   'params' => {
                                     'message_id' => 'in-msg-1',
                                     'context' => 'default',
                                     'direction' => 'inbound',
                                     'from_number' => '+15551110000',
                                     'to_number' => '+15552220000',
                                     'body' => 'hello back',
                                     'media' => [],
                                     'segments' => 1,
                                     'message_state' => 'received',
                                     'tags' => ['incoming']
                                   }
                                 }
                               })
    Timeout.timeout(5) { @inbound = received_q.pop }

    assert_equal 'in-msg-1',     @inbound.message_id
    assert_equal 'inbound',      @inbound.direction
    assert_equal '+15551110000', @inbound.from_number
    assert_equal '+15552220000', @inbound.to_number
    assert_equal 'hello back',   @inbound.body
    assert_equal ['incoming'],   @inbound.tags
  end

  # ---- Full state progression -------------------------------------------

  def test_full_message_state_progression
    msg = @client.send_message(
      to_number: '+15551112222',
      from_number: '+15553334444',
      body: 'full pipeline'
    )
    push_message_state(msg.message_id, 'sent')
    deadline = Time.now + 2
    sleep 0.02 until msg.state == 'sent' || Time.now > deadline

    assert_equal 'sent', msg.state

    push_message_state(msg.message_id, 'delivered')
    msg.wait(timeout: 5)

    assert_equal 'delivered', msg.state
  end

  private

  def push_message_state(message_id, state, extra: {})
    params = { 'message_id' => message_id, 'message_state' => state }
    params.merge!(extra)
    RelayMockTest.journal.push({
                                 'jsonrpc' => '2.0',
                                 'id' => SecureRandom.uuid,
                                 'method' => 'signalwire.event',
                                 'params' => {
                                   'event_type' => 'messaging.state',
                                   'params' => params
                                 }
                               })
  end
end
