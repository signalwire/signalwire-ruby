# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/relay/constants'
require_relative '../lib/signalwire/relay/relay_event'
require_relative '../lib/signalwire/relay/action'
require_relative '../lib/signalwire/relay/call'
require_relative '../lib/signalwire/relay/message'
# Client require deferred to avoid websocket dependency in unit tests

class RelayConstantsTest < Minitest::Test
  def test_protocol_version
    assert_equal 2, SignalWire::Relay::PROTOCOL_VERSION['major']
    assert_equal 0, SignalWire::Relay::PROTOCOL_VERSION['minor']
    assert_equal 0, SignalWire::Relay::PROTOCOL_VERSION['revision']
  end

  def test_agent_string
    assert_match(/signalwire-agents-ruby/, SignalWire::Relay::AGENT_STRING)
  end

  def test_call_states_defined
    assert_equal 'created',  SignalWire::Relay::CALL_STATE_CREATED
    assert_equal 'ringing',  SignalWire::Relay::CALL_STATE_RINGING
    assert_equal 'answered', SignalWire::Relay::CALL_STATE_ANSWERED
    assert_equal 'ending',   SignalWire::Relay::CALL_STATE_ENDING
    assert_equal 'ended',    SignalWire::Relay::CALL_STATE_ENDED
    assert_equal 5, SignalWire::Relay::CALL_STATES.length
  end

  def test_end_reasons_defined
    assert_equal 'hangup',   SignalWire::Relay::END_REASON_HANGUP
    assert_equal 'cancel',   SignalWire::Relay::END_REASON_CANCEL
    assert_equal 'busy',     SignalWire::Relay::END_REASON_BUSY
    assert_equal 'noAnswer', SignalWire::Relay::END_REASON_NO_ANSWER
    assert_equal 'decline',  SignalWire::Relay::END_REASON_DECLINE
    assert_equal 'error',    SignalWire::Relay::END_REASON_ERROR
  end

  def test_event_types_defined
    assert_equal 'calling.call.state',   SignalWire::Relay::EVENT_CALL_STATE
    assert_equal 'calling.call.receive', SignalWire::Relay::EVENT_CALL_RECEIVE
    assert_equal 'calling.call.play',    SignalWire::Relay::EVENT_CALL_PLAY
    assert_equal 'calling.call.record',  SignalWire::Relay::EVENT_CALL_RECORD
    assert_equal 'calling.call.detect',  SignalWire::Relay::EVENT_CALL_DETECT
    assert_equal 'calling.call.collect', SignalWire::Relay::EVENT_CALL_COLLECT
    assert_equal 'calling.call.fax',     SignalWire::Relay::EVENT_CALL_FAX
    assert_equal 'calling.call.tap',     SignalWire::Relay::EVENT_CALL_TAP
    assert_equal 'calling.call.dial',    SignalWire::Relay::EVENT_CALL_DIAL
    assert_equal 'calling.call.stream',  SignalWire::Relay::EVENT_CALL_STREAM
    assert_equal 'calling.call.echo',    SignalWire::Relay::EVENT_CALL_ECHO
  end

  def test_message_states_defined
    assert_equal 'queued',      SignalWire::Relay::MESSAGE_STATE_QUEUED
    assert_equal 'delivered',   SignalWire::Relay::MESSAGE_STATE_DELIVERED
    assert_equal 'failed',      SignalWire::Relay::MESSAGE_STATE_FAILED
    assert_equal 'undelivered', SignalWire::Relay::MESSAGE_STATE_UNDELIVERED
    assert_includes SignalWire::Relay::MESSAGE_TERMINAL_STATES, 'delivered'
    assert_includes SignalWire::Relay::MESSAGE_TERMINAL_STATES, 'undelivered'
    assert_includes SignalWire::Relay::MESSAGE_TERMINAL_STATES, 'failed'
  end

  def test_messaging_event_types
    assert_equal 'messaging.receive', SignalWire::Relay::EVENT_MESSAGING_RECEIVE
    assert_equal 'messaging.state',   SignalWire::Relay::EVENT_MESSAGING_STATE
  end

  def test_play_states
    assert_equal 'playing',  SignalWire::Relay::PLAY_STATE_PLAYING
    assert_equal 'paused',   SignalWire::Relay::PLAY_STATE_PAUSED
    assert_equal 'finished', SignalWire::Relay::PLAY_STATE_FINISHED
    assert_equal 'error',    SignalWire::Relay::PLAY_STATE_ERROR
  end

  def test_record_states
    assert_equal 'recording', SignalWire::Relay::RECORD_STATE_RECORDING
    assert_equal 'finished',  SignalWire::Relay::RECORD_STATE_FINISHED
    assert_equal 'no_input',  SignalWire::Relay::RECORD_STATE_NO_INPUT
  end

  def test_reconnect_settings
    assert_equal 1.0,  SignalWire::Relay::RECONNECT_MIN_DELAY
    assert_equal 30.0, SignalWire::Relay::RECONNECT_MAX_DELAY
    assert_equal 2.0,  SignalWire::Relay::RECONNECT_BACKOFF_FACTOR
  end

  def test_default_host
    assert_equal 'relay.signalwire.com', SignalWire::Relay::DEFAULT_RELAY_HOST
  end
end

class RelayEventParsingTest < Minitest::Test
  def test_base_event_from_payload
    payload = {
      'event_type' => 'calling.call.state',
      'params' => {
        'call_id' => 'abc-123',
        'timestamp' => 1234567.89
      }
    }
    event = SignalWire::Relay::RelayEvent.from_payload(payload)
    assert_equal 'calling.call.state', event.event_type
    assert_equal 'abc-123', event.call_id
    assert_equal 1234567.89, event.timestamp
    assert_equal 'abc-123', event.params['call_id']
  end

  def test_call_state_event
    payload = {
      'event_type' => 'calling.call.state',
      'params' => {
        'call_id' => 'c1',
        'call_state' => 'answered',
        'end_reason' => '',
        'direction' => 'inbound',
        'device' => { 'type' => 'phone' }
      }
    }
    event = SignalWire::Relay::CallStateEvent.from_payload(payload)
    assert_instance_of SignalWire::Relay::CallStateEvent, event
    assert_equal 'answered', event.call_state
    assert_equal 'inbound', event.direction
    assert_equal({ 'type' => 'phone' }, event.device)
  end

  def test_call_receive_event
    payload = {
      'event_type' => 'calling.call.receive',
      'params' => {
        'call_id' => 'c2',
        'node_id' => 'n1',
        'project_id' => 'p1',
        'context' => 'office',
        'direction' => 'inbound',
        'call_state' => 'ringing',
        'tag' => 'tag-1',
        'segment_id' => 'seg-1',
        'device' => {}
      }
    }
    event = SignalWire::Relay::CallReceiveEvent.from_payload(payload)
    assert_equal 'c2', event.call_id
    assert_equal 'n1', event.node_id
    assert_equal 'p1', event.project_id
    assert_equal 'office', event.context
    assert_equal 'tag-1', event.tag
  end

  def test_play_event
    payload = {
      'event_type' => 'calling.call.play',
      'params' => {
        'call_id' => 'c1',
        'control_id' => 'ctl-1',
        'state' => 'finished'
      }
    }
    event = SignalWire::Relay::PlayEvent.from_payload(payload)
    assert_equal 'ctl-1', event.control_id
    assert_equal 'finished', event.state
  end

  def test_record_event_with_nested_record
    payload = {
      'event_type' => 'calling.call.record',
      'params' => {
        'call_id' => 'c1',
        'control_id' => 'ctl-2',
        'state' => 'finished',
        'record' => {
          'url' => 'https://example.com/rec.mp3',
          'duration' => 30.5,
          'size' => 102400
        }
      }
    }
    event = SignalWire::Relay::RecordEvent.from_payload(payload)
    assert_equal 'https://example.com/rec.mp3', event.url
    assert_equal 30.5, event.duration
    assert_equal 102400, event.size
  end

  def test_collect_event
    payload = {
      'event_type' => 'calling.call.collect',
      'params' => {
        'call_id' => 'c1',
        'control_id' => 'ctl-3',
        'state' => 'finished',
        'result' => { 'type' => 'digit', 'params' => { 'digits' => '1234' } }
      }
    }
    event = SignalWire::Relay::CollectEvent.from_payload(payload)
    assert_equal 'finished', event.state
    assert_equal 'digit', event.result_data['type']
  end

  def test_dial_event
    payload = {
      'event_type' => 'calling.call.dial',
      'params' => {
        'tag' => 'my-tag',
        'dial_state' => 'answered',
        'call' => {
          'call_id' => 'winner-uuid',
          'node_id' => 'node-1',
          'dial_winner' => true
        }
      }
    }
    event = SignalWire::Relay::DialEvent.from_payload(payload)
    assert_equal 'my-tag', event.tag
    assert_equal 'answered', event.dial_state
    assert_equal 'winner-uuid', event.call_data['call_id']
  end

  def test_connect_event
    payload = {
      'event_type' => 'calling.call.connect',
      'params' => {
        'call_id' => 'c1',
        'connect_state' => 'connected',
        'peer' => { 'call_id' => 'c2' }
      }
    }
    event = SignalWire::Relay::ConnectEvent.from_payload(payload)
    assert_equal 'connected', event.connect_state
    assert_equal 'c2', event.peer['call_id']
  end

  def test_detect_event
    payload = {
      'event_type' => 'calling.call.detect',
      'params' => {
        'call_id' => 'c1',
        'control_id' => 'ctl-4',
        'detect' => { 'type' => 'machine', 'params' => { 'event' => 'HUMAN' } }
      }
    }
    event = SignalWire::Relay::DetectEvent.from_payload(payload)
    assert_equal 'HUMAN', event.detect.dig('params', 'event')
  end

  def test_message_receive_event
    payload = {
      'event_type' => 'messaging.receive',
      'params' => {
        'message_id' => 'msg-1',
        'context' => 'default',
        'direction' => 'inbound',
        'from_number' => '+15551234567',
        'to_number' => '+15559876543',
        'body' => 'Hello',
        'media' => ['https://example.com/img.jpg'],
        'segments' => 1,
        'message_state' => 'received',
        'tags' => ['vip']
      }
    }
    event = SignalWire::Relay::MessageReceiveEvent.from_payload(payload)
    assert_equal 'msg-1', event.message_id
    assert_equal '+15551234567', event.from_number
    assert_equal 'Hello', event.body
    assert_equal ['vip'], event.tags
  end

  def test_message_state_event
    payload = {
      'event_type' => 'messaging.state',
      'params' => {
        'message_id' => 'msg-2',
        'message_state' => 'delivered',
        'direction' => 'outbound',
        'from_number' => '+15551111111',
        'to_number' => '+15552222222',
        'body' => 'Test',
        'reason' => ''
      }
    }
    event = SignalWire::Relay::MessageStateEvent.from_payload(payload)
    assert_equal 'msg-2', event.message_id
    assert_equal 'delivered', event.message_state
    assert_equal '', event.reason
  end

  def test_parse_event_routing
    # Test that parse_event routes to correct subclass
    payload = {
      'event_type' => 'calling.call.play',
      'params' => { 'control_id' => 'x', 'state' => 'playing' }
    }
    event = SignalWire::Relay.parse_event(payload)
    assert_instance_of SignalWire::Relay::PlayEvent, event

    # Unknown event types get base RelayEvent
    payload = {
      'event_type' => 'unknown.event',
      'params' => {}
    }
    event = SignalWire::Relay.parse_event(payload)
    assert_instance_of SignalWire::Relay::RelayEvent, event
  end

  def test_event_class_map_completeness
    map = SignalWire::Relay::EVENT_CLASS_MAP
    assert map.key?('calling.call.state')
    assert map.key?('calling.call.receive')
    assert map.key?('calling.call.play')
    assert map.key?('calling.call.record')
    assert map.key?('calling.call.collect')
    assert map.key?('calling.call.connect')
    assert map.key?('calling.call.detect')
    assert map.key?('calling.call.fax')
    assert map.key?('calling.call.tap')
    assert map.key?('calling.call.stream')
    assert map.key?('calling.call.send_digits')
    assert map.key?('calling.call.dial')
    assert map.key?('calling.call.refer')
    assert map.key?('calling.call.denoise')
    assert map.key?('calling.call.pay')
    assert map.key?('calling.call.queue')
    assert map.key?('calling.call.echo')
    assert map.key?('calling.call.transcribe')
    assert map.key?('calling.call.hold')
    assert map.key?('calling.conference')
    assert map.key?('calling.error')
    assert map.key?('messaging.receive')
    assert map.key?('messaging.state')
    assert_equal 23, map.size
  end

  def test_conference_event
    payload = {
      'event_type' => 'calling.conference',
      'params' => {
        'conference_id' => 'conf-1',
        'name' => 'standup',
        'status' => 'active'
      }
    }
    event = SignalWire::Relay::ConferenceEvent.from_payload(payload)
    assert_equal 'conf-1', event.conference_id
    assert_equal 'standup', event.name
    assert_equal 'active', event.status
  end

  def test_calling_error_event
    payload = {
      'event_type' => 'calling.error',
      'params' => {
        'code' => '500',
        'message' => 'Internal error'
      }
    }
    event = SignalWire::Relay::CallingErrorEvent.from_payload(payload)
    assert_equal '500', event.code
    assert_equal 'Internal error', event.message
  end
end

class RelayActionTest < Minitest::Test
  # Stub client that records execute calls
  class StubClient
    attr_reader :executed

    def initialize
      @executed = []
    end

    def execute(method, params)
      @executed << [method, params]
      { 'code' => '200', 'message' => 'OK' }
    end
  end

  def setup
    @stub_client = StubClient.new
    @call = SignalWire::Relay::Call.new(
      @stub_client,
      call_id: 'test-call-1',
      node_id: 'test-node-1',
      state: 'answered'
    )
  end

  def test_action_wait_and_resolve
    action = SignalWire::Relay::Action.new(
      @call, 'ctl-1', 'calling.call.play', %w[finished error]
    )

    refute action.done?
    assert_nil action.result

    # Resolve in a thread
    event = SignalWire::Relay::RelayEvent.new(
      event_type: 'calling.call.play',
      params: { 'state' => 'finished' }
    )

    Thread.new do
      sleep 0.05
      action._check_event(event)
    end

    result = action.wait(timeout: 2)
    assert action.done?
    assert_equal event, result
    assert action.is_done?
  end

  def test_action_timeout
    action = SignalWire::Relay::Action.new(
      @call, 'ctl-2', 'calling.call.play', %w[finished error]
    )

    assert_raises(SignalWire::Relay::ActionTimeoutError) do
      action.wait(timeout: 0.05)
    end
  end

  def test_action_on_completed_callback
    action = SignalWire::Relay::Action.new(
      @call, 'ctl-3', 'calling.call.play', %w[finished error]
    )

    callback_called = false
    callback_event = nil
    action.on_completed do |ev|
      callback_called = true
      callback_event = ev
    end

    event = SignalWire::Relay::RelayEvent.new(
      event_type: 'calling.call.play',
      params: { 'state' => 'finished' }
    )
    action._resolve(event)

    assert callback_called
    assert_equal event, callback_event
  end

  def test_action_double_resolve_ignored
    action = SignalWire::Relay::Action.new(
      @call, 'ctl-4', 'calling.call.play', %w[finished error]
    )

    count = 0
    action.on_completed { count += 1 }

    event = SignalWire::Relay::RelayEvent.new(
      event_type: 'calling.call.play',
      params: { 'state' => 'finished' }
    )
    action._resolve(event)
    action._resolve(event)

    assert_equal 1, count
  end

  def test_play_action_class
    action = SignalWire::Relay::PlayAction.new(@call, 'play-ctl-1')
    assert_equal 'play-ctl-1', action.control_id
    assert_equal @call, action.call
    refute action.done?
  end

  def test_record_action_class
    action = SignalWire::Relay::RecordAction.new(@call, 'rec-ctl-1')
    assert_equal 'rec-ctl-1', action.control_id
  end

  def test_detect_action_resolves_on_detect_data
    action = SignalWire::Relay::DetectAction.new(@call, 'det-ctl-1')

    # Detect should resolve on first meaningful detect data
    event = SignalWire::Relay::RelayEvent.new(
      event_type: 'calling.call.detect',
      params: {
        'control_id' => 'det-ctl-1',
        'detect' => { 'type' => 'machine', 'params' => { 'event' => 'HUMAN' } }
      }
    )
    action._check_event(event)
    assert action.done?
  end

  def test_collect_action_only_resolves_on_collect_event
    action = SignalWire::Relay::CollectAction.new(@call, 'col-ctl-1')

    # Play event should NOT resolve
    play_event = SignalWire::Relay::RelayEvent.new(
      event_type: 'calling.call.play',
      params: { 'control_id' => 'col-ctl-1', 'state' => 'finished' }
    )
    action._check_event(play_event)
    refute action.done?

    # Collect event SHOULD resolve
    collect_event = SignalWire::Relay::RelayEvent.new(
      event_type: 'calling.call.collect',
      params: {
        'control_id' => 'col-ctl-1',
        'result' => { 'type' => 'digit', 'params' => { 'digits' => '1234' } }
      }
    )
    action._check_event(collect_event)
    assert action.done?
  end

  def test_fax_action
    action = SignalWire::Relay::FaxAction.new(@call, 'fax-ctl-1', 'send_fax')
    assert_equal 'fax-ctl-1', action.control_id
  end

  def test_tap_action
    action = SignalWire::Relay::TapAction.new(@call, 'tap-ctl-1')
    assert_equal 'tap-ctl-1', action.control_id
  end

  def test_stream_action
    action = SignalWire::Relay::StreamAction.new(@call, 'str-ctl-1')
    assert_equal 'str-ctl-1', action.control_id
  end

  def test_pay_action
    action = SignalWire::Relay::PayAction.new(@call, 'pay-ctl-1')
    assert_equal 'pay-ctl-1', action.control_id
  end

  def test_transcribe_action
    action = SignalWire::Relay::TranscribeAction.new(@call, 'txn-ctl-1')
    assert_equal 'txn-ctl-1', action.control_id
  end

  def test_ai_action
    action = SignalWire::Relay::AIAction.new(@call, 'ai-ctl-1')
    assert_equal 'ai-ctl-1', action.control_id
  end
end

class RelayCallTest < Minitest::Test
  class StubClient
    attr_reader :executed

    def initialize
      @executed = []
    end

    def execute(method, params)
      @executed << [method, params]
      { 'code' => '200', 'message' => 'OK' }
    end
  end

  def setup
    @stub_client = StubClient.new
    @call = SignalWire::Relay::Call.new(
      @stub_client,
      call_id: 'call-1',
      node_id: 'node-1',
      project_id: 'proj-1',
      context: 'default',
      tag: 'tag-1',
      direction: 'inbound',
      state: 'answered'
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
    assert_match(/inbound/, str)
  end

  def test_call_dispatch_state_event
    payload = {
      'event_type' => 'calling.call.state',
      'params' => {
        'call_id' => 'call-1',
        'call_state' => 'ended',
        'end_reason' => 'hangup'
      }
    }
    @call._dispatch_event(payload)
    assert_equal 'ended', @call.state
    assert @call.ended?
  end

  def test_call_event_listener
    events_received = []
    @call.on('calling.call.state') { |e| events_received << e }

    payload = {
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'call-1', 'call_state' => 'ending' }
    }
    @call._dispatch_event(payload)

    assert_equal 1, events_received.length
    assert_instance_of SignalWire::Relay::CallStateEvent, events_received[0]
  end

  def test_call_action_routing
    # Start a play action
    action = @call.play([{ 'type' => 'audio', 'params' => { 'url' => 'http://test.wav' } }])
    assert_instance_of SignalWire::Relay::PlayAction, action
    refute action.done?

    # Verify RPC was sent
    assert_equal 1, @stub_client.executed.length
    method, params = @stub_client.executed[0]
    assert_equal 'calling.play', method
    assert_equal 'node-1', params['node_id']
    assert_equal 'call-1', params['call_id']
  end

  def test_call_answer
    @call.answer
    assert_equal 1, @stub_client.executed.length
    method, = @stub_client.executed[0]
    assert_equal 'calling.answer', method
  end

  def test_call_hangup
    @call.hangup
    method, params = @stub_client.executed[0]
    assert_equal 'calling.end', method
    assert_equal 'hangup', params['reason']
  end

  def test_call_ended_resolves_pending_actions
    action = @call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hello' } }])
    refute action.done?

    # Simulate call ended
    payload = {
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'call-1', 'call_state' => 'ended' }
    }
    @call._dispatch_event(payload)

    assert action.done?
    assert @call.ended?
  end

  def test_call_start_action_on_ended_call
    @call.state = 'ended'
    # Trigger ended state internally
    payload = {
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'call-1', 'call_state' => 'ended' }
    }
    @call._dispatch_event(payload)

    action = @call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hello' } }])
    assert action.done?
    # No RPC should have been sent for the play (only the dispatched state event)
  end

  def test_call_record
    action = @call.record(audio: { 'format' => 'mp3' })
    assert_instance_of SignalWire::Relay::RecordAction, action
    method, params = @stub_client.executed[0]
    assert_equal 'calling.record', method
    assert_equal({ 'audio' => { 'format' => 'mp3' } }, params['record'])
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
end

class RelayMessageTest < Minitest::Test
  def test_message_creation
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-1',
      context: 'default',
      direction: 'outbound',
      from_number: '+15551111111',
      to_number: '+15552222222',
      body: 'Hello',
      state: 'queued'
    )
    assert_equal 'msg-1', msg.message_id
    assert_equal 'outbound', msg.direction
    assert_equal '+15551111111', msg.from_number
    assert_equal 'Hello', msg.body
    assert_equal 'queued', msg.state
    refute msg.done?
    assert_nil msg.result
  end

  def test_message_state_dispatch
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-2',
      state: 'queued'
    )

    # Dispatch state change
    payload = {
      'event_type' => 'messaging.state',
      'params' => {
        'message_id' => 'msg-2',
        'message_state' => 'sent'
      }
    }
    msg._dispatch_event(payload)
    assert_equal 'sent', msg.state
    refute msg.done?

    # Dispatch terminal state
    payload = {
      'event_type' => 'messaging.state',
      'params' => {
        'message_id' => 'msg-2',
        'message_state' => 'delivered'
      }
    }
    msg._dispatch_event(payload)
    assert_equal 'delivered', msg.state
    assert msg.done?
    assert_kind_of SignalWire::Relay::RelayEvent, msg.result
  end

  def test_message_wait_with_timeout
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-3',
      state: 'queued'
    )

    # Resolve in a thread
    Thread.new do
      sleep 0.05
      payload = {
        'event_type' => 'messaging.state',
        'params' => {
          'message_id' => 'msg-3',
          'message_state' => 'delivered'
        }
      }
      msg._dispatch_event(payload)
    end

    result = msg.wait(timeout: 2)
    assert msg.done?
    assert_kind_of SignalWire::Relay::RelayEvent, result
  end

  def test_message_on_completed
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-4',
      state: 'queued'
    )

    callback_fired = false
    msg.on_completed { callback_fired = true }

    payload = {
      'event_type' => 'messaging.state',
      'params' => {
        'message_id' => 'msg-4',
        'message_state' => 'failed',
        'reason' => 'carrier error'
      }
    }
    msg._dispatch_event(payload)

    assert callback_fired
    assert_equal 'carrier error', msg.reason
  end

  def test_message_event_listener
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-5',
      state: 'queued'
    )

    events = []
    msg.on_event { |e| events << e }

    payload = {
      'event_type' => 'messaging.state',
      'params' => {
        'message_id' => 'msg-5',
        'message_state' => 'sent'
      }
    }
    msg._dispatch_event(payload)

    assert_equal 1, events.length
  end

  def test_message_to_s
    msg = SignalWire::Relay::Message.new(
      message_id: 'msg-6',
      direction: 'outbound',
      state: 'queued',
      from_number: '+15551111111',
      to_number: '+15552222222'
    )
    str = msg.to_s
    assert_match(/msg-6/, str)
    assert_match(/outbound/, str)
  end
end

class RelayClientCreationTest < Minitest::Test
  def test_client_class_exists
    # Load client module
    require_relative '../lib/signalwire/relay/client'
    assert defined?(SignalWire::Relay::Client)
    assert defined?(SignalWire::Relay::RelayError)
  end

  def test_client_requires_credentials
    require_relative '../lib/signalwire/relay/client'

    # Clear env vars temporarily
    old_project = ENV.delete('SIGNALWIRE_PROJECT_ID')
    old_token = ENV.delete('SIGNALWIRE_API_TOKEN')
    old_space = ENV.delete('SIGNALWIRE_SPACE')

    begin
      assert_raises(ArgumentError) do
        SignalWire::Relay::Client.new
      end

      assert_raises(ArgumentError) do
        SignalWire::Relay::Client.new(project: 'proj', token: 'tok')
      end
    ensure
      ENV['SIGNALWIRE_PROJECT_ID'] = old_project if old_project
      ENV['SIGNALWIRE_API_TOKEN'] = old_token if old_token
      ENV['SIGNALWIRE_SPACE'] = old_space if old_space
    end
  end

  def test_client_creation_with_options
    require_relative '../lib/signalwire/relay/client'

    client = SignalWire::Relay::Client.new(
      project: 'test-project',
      token: 'test-token',
      space: 'example.signalwire.com'
    )
    assert_equal 'test-project', client.project_id
    assert_nil client.protocol
  end

  def test_client_creation_with_short_space
    require_relative '../lib/signalwire/relay/client'

    client = SignalWire::Relay::Client.new(
      project: 'test-project',
      token: 'test-token',
      space: 'myspace'
    )
    assert_equal 'test-project', client.project_id
  end

  def test_relay_error
    require_relative '../lib/signalwire/relay/client'

    err = SignalWire::Relay::RelayError.new(404, 'Not found')
    assert_equal 404, err.code
    assert_equal 'Not found', err.error_message
    assert_match(/404/, err.message)
    assert_match(/Not found/, err.message)
  end
end
