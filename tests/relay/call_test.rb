# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/relay/constants'
require_relative '../../lib/signalwire/relay/relay_event'
require_relative '../../lib/signalwire/relay/action'
require_relative '../../lib/signalwire/relay/call'

class RelayCallDetailedTest < Minitest::Test
  class StubClient
    attr_reader :executed

    def initialize = @executed = []

    def execute(method, params)
      @executed << [method, params]
      { 'code' => '200', 'message' => 'OK' }
    end
  end

  def setup
    @stub_client = StubClient.new
    @call = SignalWire::Relay::Call.new(
      @stub_client,
      call_id: 'call-1', node_id: 'node-1', project_id: 'proj-1',
      context: 'default', tag: 'tag-1', direction: 'inbound', state: 'answered'
    )
  end

  def test_call_properties
    assert_equal 'call-1', @call.call_id
    assert_equal 'node-1', @call.node_id
    assert_equal 'proj-1', @call.project_id
    assert_equal 'default', @call.context
    assert_equal 'tag-1', @call.tag
    assert_equal 'inbound', @call.direction
    assert_equal 'answered', @call.state
  end

  def test_call_to_s
    str = @call.to_s

    assert_match(/call-1/, str)
    assert_match(/answered/, str)
  end

  def test_call_answer
    @call.answer
    method, = @stub_client.executed[0]

    assert_equal 'calling.answer', method
  end

  def test_call_hangup
    @call.hangup
    method, params = @stub_client.executed[0]

    assert_equal 'calling.end', method
    assert_equal 'hangup', params['reason']
  end

  def test_call_play
    action = @call.play([{ 'type' => 'audio', 'params' => { 'url' => 'http://test.wav' } }])

    assert_instance_of SignalWire::Relay::PlayAction, action
    method, params = @stub_client.executed[0]

    assert_equal 'calling.play', method
    assert_equal 'node-1', params['node_id']
  end

  def test_call_record
    action = @call.record(audio: { 'format' => 'mp3' })

    assert_instance_of SignalWire::Relay::RecordAction, action
    method, = @stub_client.executed[0]

    assert_equal 'calling.record', method
  end

  def test_call_detect
    action = @call.detect({ 'type' => 'machine', 'params' => {} })

    assert_instance_of SignalWire::Relay::DetectAction, action
    method, = @stub_client.executed[0]

    assert_equal 'calling.detect', method
  end

  def test_call_transcribe
    action = @call.transcribe

    assert_instance_of SignalWire::Relay::TranscribeAction, action
    method, = @stub_client.executed[0]

    assert_equal 'calling.transcribe', method
  end

  def test_call_stream
    action = @call.stream(url: 'wss://test.example.com')

    assert_instance_of SignalWire::Relay::StreamAction, action
    method, params = @stub_client.executed[0]

    assert_equal 'calling.stream', method
    assert_equal 'wss://test.example.com', params['url']
  end

  def test_call_ai
    action = @call.ai(prompt: { 'text' => 'You are helpful' })

    assert_instance_of SignalWire::Relay::AIAction, action
    method, = @stub_client.executed[0]

    assert_equal 'calling.ai', method
  end

  def test_state_update_on_event
    payload = {
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'call-1', 'call_state' => 'ended', 'end_reason' => 'hangup' }
    }
    @call._dispatch_event(payload)

    assert_equal 'ended', @call.state
    assert_predicate @call, :ended?
  end

  def test_ended_resolves_pending_actions
    action = @call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hello' } }])

    refute_predicate action, :done?
    payload = {
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'call-1', 'call_state' => 'ended' }
    }
    @call._dispatch_event(payload)

    assert_predicate action, :done?
  end
end
