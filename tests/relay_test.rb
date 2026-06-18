# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/relay/constants'
require_relative '../lib/signalwire/relay/relay_event'
require_relative '../lib/signalwire/relay/action'
require_relative '../lib/signalwire/relay/call'
require_relative '../lib/signalwire/relay/message'
# Client require deferred to avoid websocket dependency in unit tests

# Shared RELAY-payload builder for the event-parsing tests.
module RelayPayloadHelpers
  # Wrap +params+ in a RELAY event envelope for the given +event_type+.
  def payload(event_type, params)
    { 'event_type' => event_type, 'params' => params }
  end

  # Build a RelayEvent of +event_type+ carrying +params+.
  def relay_event(event_type, params)
    SignalWire::Relay::RelayEvent.new(event_type: event_type, params: params)
  end
end

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

  EVENT_TYPE_CONSTANTS = {
    EVENT_CALL_STATE: 'calling.call.state', EVENT_CALL_RECEIVE: 'calling.call.receive',
    EVENT_CALL_PLAY: 'calling.call.play', EVENT_CALL_RECORD: 'calling.call.record',
    EVENT_CALL_DETECT: 'calling.call.detect', EVENT_CALL_COLLECT: 'calling.call.collect',
    EVENT_CALL_FAX: 'calling.call.fax', EVENT_CALL_TAP: 'calling.call.tap',
    EVENT_CALL_DIAL: 'calling.call.dial', EVENT_CALL_STREAM: 'calling.call.stream',
    EVENT_CALL_ECHO: 'calling.call.echo'
  }.freeze

  def test_event_types_defined
    EVENT_TYPE_CONSTANTS.each do |const, wire|
      assert_equal wire, SignalWire::Relay.const_get(const)
    end
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
    assert_in_delta(1.0, SignalWire::Relay::RECONNECT_MIN_DELAY)
    assert_in_delta(30.0, SignalWire::Relay::RECONNECT_MAX_DELAY)
    assert_in_delta(2.0, SignalWire::Relay::RECONNECT_BACKOFF_FACTOR)
  end

  def test_default_host
    assert_equal 'relay.signalwire.com', SignalWire::Relay::DEFAULT_RELAY_HOST
  end
end

class RelayEventParsingTest < Minitest::Test
  include RelayPayloadHelpers

  def test_base_event_from_payload
    event = SignalWire::Relay::RelayEvent.from_payload(
      payload('calling.call.state', 'call_id' => 'abc-123', 'timestamp' => 1_234_567.89)
    )

    assert_equal 'calling.call.state', event.event_type
    assert_equal 'abc-123', event.call_id
    assert_in_delta(1_234_567.89, event.timestamp)
    assert_equal 'abc-123', event.params['call_id']
  end

  def test_call_state_event
    event = SignalWire::Relay::CallStateEvent.from_payload(
      payload('calling.call.state', 'call_id' => 'c1', 'call_state' => 'answered', 'end_reason' => '',
                                    'direction' => 'inbound', 'device' => { 'type' => 'phone' })
    )

    assert_instance_of SignalWire::Relay::CallStateEvent, event
    assert_equal 'answered', event.call_state
    assert_equal 'inbound', event.direction
    assert_equal({ 'type' => 'phone' }, event.device)
  end

  def test_call_receive_event
    event = SignalWire::Relay::CallReceiveEvent.from_payload(
      payload('calling.call.receive', 'call_id' => 'c2', 'node_id' => 'n1', 'project_id' => 'p1',
                                      'context' => 'office', 'direction' => 'inbound', 'call_state' => 'ringing',
                                      'tag' => 'tag-1', 'segment_id' => 'seg-1', 'device' => {})
    )

    assert_equal 'c2', event.call_id
    assert_equal 'n1', event.node_id
    assert_equal 'p1', event.project_id
    assert_equal 'office', event.context
    assert_equal 'tag-1', event.tag
  end

  def test_play_event
    event = SignalWire::Relay::PlayEvent.from_payload(
      payload('calling.call.play', 'call_id' => 'c1', 'control_id' => 'ctl-1', 'state' => 'finished')
    )

    assert_equal 'ctl-1', event.control_id
    assert_equal 'finished', event.state
  end

  def test_record_event_with_nested_record
    record = { 'url' => 'https://example.com/rec.mp3', 'duration' => 30.5, 'size' => 102_400 }
    event = SignalWire::Relay::RecordEvent.from_payload(
      payload('calling.call.record', 'call_id' => 'c1', 'control_id' => 'ctl-2', 'state' => 'finished',
                                     'record' => record)
    )

    assert_equal 'https://example.com/rec.mp3', event.url
    assert_in_delta(30.5, event.duration)
    assert_equal 102_400, event.size
  end

  def test_collect_event
    result = { 'type' => 'digit', 'params' => { 'digits' => '1234' } }
    event = SignalWire::Relay::CollectEvent.from_payload(
      payload('calling.call.collect', 'call_id' => 'c1', 'control_id' => 'ctl-3', 'state' => 'finished',
                                      'result' => result)
    )

    assert_equal 'finished', event.state
    assert_equal 'digit', event.result_data['type']
  end

  def test_dial_event
    call = { 'call_id' => 'winner-uuid', 'node_id' => 'node-1', 'dial_winner' => true }
    event = SignalWire::Relay::DialEvent.from_payload(
      payload('calling.call.dial', 'tag' => 'my-tag', 'dial_state' => 'answered', 'call' => call)
    )

    assert_equal 'my-tag', event.tag
    assert_equal 'answered', event.dial_state
    assert_equal 'winner-uuid', event.call_data['call_id']
  end

  def test_connect_event
    event = SignalWire::Relay::ConnectEvent.from_payload(
      payload('calling.call.connect', 'call_id' => 'c1', 'connect_state' => 'connected',
                                      'peer' => { 'call_id' => 'c2' })
    )

    assert_equal 'connected', event.connect_state
    assert_equal 'c2', event.peer['call_id']
  end

  def test_detect_event
    detect = { 'type' => 'machine', 'params' => { 'event' => 'HUMAN' } }
    event = SignalWire::Relay::DetectEvent.from_payload(
      payload('calling.call.detect', 'call_id' => 'c1', 'control_id' => 'ctl-4', 'detect' => detect)
    )

    assert_equal 'HUMAN', event.detect.dig('params', 'event')
  end

  def test_conference_event
    event = SignalWire::Relay::ConferenceEvent.from_payload(
      payload('calling.conference', 'conference_id' => 'conf-1', 'name' => 'standup', 'status' => 'active')
    )

    assert_equal 'conf-1', event.conference_id
    assert_equal 'standup', event.name
    assert_equal 'active', event.status
  end

  def test_calling_error_event
    event = SignalWire::Relay::CallingErrorEvent.from_payload(
      payload('calling.error', 'code' => '500', 'message' => 'Internal error')
    )

    assert_equal '500', event.code
    assert_equal 'Internal error', event.message
  end
end

# Messaging-event parsing, parse_event routing, and the EVENT_CLASS_MAP
# completeness check (split from RelayEventParsingTest to keep each class
# under the size limit).
class RelayMessagingAndRoutingParsingTest < Minitest::Test
  include RelayPayloadHelpers

  def test_message_receive_event
    params = { 'message_id' => 'msg-1', 'context' => 'default', 'direction' => 'inbound',
               'from_number' => '+15551234567', 'to_number' => '+15559876543', 'body' => 'Hello',
               'media' => ['https://example.com/img.jpg'], 'segments' => 1,
               'message_state' => 'received', 'tags' => ['vip'] }
    event = SignalWire::Relay::MessageReceiveEvent.from_payload(payload('messaging.receive', params))

    assert_equal 'msg-1', event.message_id
    assert_equal '+15551234567', event.from_number
    assert_equal 'Hello', event.body
    assert_equal ['vip'], event.tags
  end

  def test_message_state_event
    params = { 'message_id' => 'msg-2', 'message_state' => 'delivered', 'direction' => 'outbound',
               'from_number' => '+15551111111', 'to_number' => '+15552222222', 'body' => 'Test', 'reason' => '' }
    event = SignalWire::Relay::MessageStateEvent.from_payload(payload('messaging.state', params))

    assert_equal 'msg-2', event.message_id
    assert_equal 'delivered', event.message_state
    assert_equal '', event.reason
  end

  def test_parse_event_routing
    # parse_event routes to the correct subclass...
    event = SignalWire::Relay.parse_event(payload('calling.call.play', 'control_id' => 'x', 'state' => 'playing'))

    assert_instance_of SignalWire::Relay::PlayEvent, event

    # ...and unknown event types fall back to the base RelayEvent.
    event = SignalWire::Relay.parse_event(payload('unknown.event', {}))

    assert_instance_of SignalWire::Relay::RelayEvent, event
  end

  EXPECTED_EVENT_KEYS = %w[
    calling.call.state calling.call.receive calling.call.play calling.call.record
    calling.call.collect calling.call.connect calling.call.detect calling.call.fax
    calling.call.tap calling.call.stream calling.call.send_digits calling.call.dial
    calling.call.refer calling.call.denoise calling.call.pay calling.call.queue
    calling.call.echo calling.call.transcribe calling.call.hold calling.conference
    calling.error messaging.receive messaging.state
  ].freeze

  def test_event_class_map_completeness
    map = SignalWire::Relay::EVENT_CLASS_MAP

    EXPECTED_EVENT_KEYS.each { |key| assert(map.key?(key), "EVENT_CLASS_MAP missing #{key}") }
    assert_equal 23, map.size
  end
end

class RelayActionTest < Minitest::Test
  include RelayPayloadHelpers

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

  # Deliver +event+ to +action+ after a short delay, on a background thread.
  def resolve_async(action, event)
    Thread.new do
      sleep 0.05
      action._check_event(event)
    end
  end

  def test_action_wait_and_resolve
    action = SignalWire::Relay::Action.new(@call, 'ctl-1', 'calling.call.play', %w[finished error])

    refute_predicate action, :done?
    assert_nil action.result

    event = relay_event('calling.call.play', 'state' => 'finished')
    resolve_async(action, event)
    result = action.wait(timeout: 2)

    assert_predicate action, :done?
    assert_equal event, result
    assert_predicate action, :is_done?
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
    action = SignalWire::Relay::Action.new(@call, 'ctl-3', 'calling.call.play', %w[finished error])

    callback_event = nil
    action.on_completed { |ev| callback_event = ev }

    event = relay_event('calling.call.play', 'state' => 'finished')
    action._resolve(event)

    assert_equal event, callback_event
  end

  def test_action_double_resolve_ignored
    action = SignalWire::Relay::Action.new(@call, 'ctl-4', 'calling.call.play', %w[finished error])

    count = 0
    action.on_completed { count += 1 }

    event = relay_event('calling.call.play', 'state' => 'finished')
    action._resolve(event)
    action._resolve(event)

    assert_equal 1, count
  end

  def test_play_action_class
    action = SignalWire::Relay::PlayAction.new(@call, 'play-ctl-1')

    assert_equal 'play-ctl-1', action.control_id
    assert_equal @call, action.call
    refute_predicate action, :done?
  end

  # Action subclasses that simply carry a control_id (constructed as
  # Klass.new(call, control_id)), mapped to a sample id.
  SIMPLE_ACTION_CLASSES = {
    SignalWire::Relay::RecordAction => 'rec-ctl-1',
    SignalWire::Relay::TapAction => 'tap-ctl-1',
    SignalWire::Relay::StreamAction => 'str-ctl-1',
    SignalWire::Relay::PayAction => 'pay-ctl-1',
    SignalWire::Relay::TranscribeAction => 'txn-ctl-1',
    SignalWire::Relay::AIAction => 'ai-ctl-1'
  }.freeze

  def test_simple_action_classes_carry_control_id
    SIMPLE_ACTION_CLASSES.each do |klass, control_id|
      assert_equal control_id, klass.new(@call, control_id).control_id, klass.name
    end
  end

  def test_fax_action_carries_control_id
    # FaxAction takes an extra method_prefix arg, so it's tested separately.
    action = SignalWire::Relay::FaxAction.new(@call, 'fax-ctl-1', 'send_fax')

    assert_equal 'fax-ctl-1', action.control_id
  end

  def test_detect_action_resolves_on_detect_data
    action = SignalWire::Relay::DetectAction.new(@call, 'det-ctl-1')

    # Detect should resolve on first meaningful detect data.
    detect = { 'type' => 'machine', 'params' => { 'event' => 'HUMAN' } }
    action._check_event(relay_event('calling.call.detect', 'control_id' => 'det-ctl-1', 'detect' => detect))

    assert_predicate action, :done?
  end

  def test_collect_action_only_resolves_on_collect_event
    action = SignalWire::Relay::CollectAction.new(@call, 'col-ctl-1')

    # Play event should NOT resolve.
    action._check_event(relay_event('calling.call.play', 'control_id' => 'col-ctl-1', 'state' => 'finished'))

    refute_predicate action, :done?

    # Collect event SHOULD resolve.
    result = { 'type' => 'digit', 'params' => { 'digits' => '1234' } }
    action._check_event(relay_event('calling.call.collect', 'control_id' => 'col-ctl-1', 'result' => result))

    assert_predicate action, :done?
  end
end

# Stub RELAY client that records execute() calls and returns a 200.
class RelayStubClient
  attr_reader :executed

  def initialize
    @executed = []
  end

  def execute(method, params)
    @executed << [method, params]
    { 'code' => '200', 'message' => 'OK' }
  end
end

# Shared setup for the RelayCall test classes: a stubbed answered inbound call.
module RelayCallSetup
  include RelayPayloadHelpers

  def setup
    @stub_client = RelayStubClient.new
    @call = SignalWire::Relay::Call.new(
      @stub_client, call_id: 'call-1', node_id: 'node-1', project_id: 'proj-1',
                    context: 'default', tag: 'tag-1', direction: 'inbound', state: 'answered'
    )
  end
end

class RelayCallTest < Minitest::Test
  include RelayCallSetup

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
    @call._dispatch_event(
      payload('calling.call.state', 'call_id' => 'call-1', 'call_state' => 'ended', 'end_reason' => 'hangup')
    )

    assert_equal 'ended', @call.state
    assert_predicate @call, :ended?
  end

  def test_call_event_listener
    events_received = []
    @call.on('calling.call.state') { |e| events_received << e }
    @call._dispatch_event(payload('calling.call.state', 'call_id' => 'call-1', 'call_state' => 'ending'))

    assert_equal 1, events_received.length
    assert_instance_of SignalWire::Relay::CallStateEvent, events_received[0]
  end

  def test_call_action_routing
    # Start a play action
    action = @call.play([{ 'type' => 'audio', 'params' => { 'url' => 'http://test.wav' } }])

    assert_instance_of SignalWire::Relay::PlayAction, action
    refute_predicate action, :done?

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

    refute_predicate action, :done?

    # Simulate call ended.
    @call._dispatch_event(payload('calling.call.state', 'call_id' => 'call-1', 'call_state' => 'ended'))

    assert_predicate action, :done?
    assert_predicate @call, :ended?
  end

  def test_call_start_action_on_ended_call
    @call.state = 'ended'
    # Trigger ended state internally.
    @call._dispatch_event(payload('calling.call.state', 'call_id' => 'call-1', 'call_state' => 'ended'))

    action = @call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hello' } }])

    assert_predicate action, :done?
    # No RPC should have been sent for the play (only the dispatched state event)
  end
end

# Call action-starter coverage (record/detect/transcribe/stream/ai), split
# from RelayCallTest to keep each class under the size limit.
class RelayCallActionsTest < Minitest::Test
  include RelayCallSetup

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
  include RelayPayloadHelpers

  # A messaging.state event payload moving +message_id+ to +state+.
  def message_state(message_id, state, extra = {})
    payload('messaging.state', { 'message_id' => message_id, 'message_state' => state }.merge(extra))
  end

  FULL_MESSAGE_ATTRS = {
    message_id: 'msg-1', context: 'default', direction: 'outbound', from_number: '+15551111111',
    to_number: '+15552222222', body: 'Hello', state: 'queued'
  }.freeze

  def test_message_creation
    msg = SignalWire::Relay::Message.new(**FULL_MESSAGE_ATTRS)

    assert_equal 'msg-1', msg.message_id
    assert_equal 'outbound', msg.direction
    assert_equal '+15551111111', msg.from_number
    assert_equal 'Hello', msg.body
    assert_equal 'queued', msg.state
    refute_predicate msg, :done?
    assert_nil msg.result
  end

  def test_message_state_dispatch
    msg = SignalWire::Relay::Message.new(message_id: 'msg-2', state: 'queued')

    # Dispatch state change.
    msg._dispatch_event(message_state('msg-2', 'sent'))

    assert_equal 'sent', msg.state
    refute_predicate msg, :done?

    # Dispatch terminal state.
    msg._dispatch_event(message_state('msg-2', 'delivered'))

    assert_equal 'delivered', msg.state
    assert_predicate msg, :done?
    assert_kind_of SignalWire::Relay::RelayEvent, msg.result
  end

  def test_message_wait_with_timeout
    msg = SignalWire::Relay::Message.new(message_id: 'msg-3', state: 'queued')

    # Resolve in a thread.
    Thread.new do
      sleep 0.05
      msg._dispatch_event(message_state('msg-3', 'delivered'))
    end
    result = msg.wait(timeout: 2)

    assert_predicate msg, :done?
    assert_kind_of SignalWire::Relay::RelayEvent, result
  end

  def test_message_on_completed
    msg = SignalWire::Relay::Message.new(message_id: 'msg-4', state: 'queued')

    callback_fired = false
    msg.on_completed { callback_fired = true }
    msg._dispatch_event(message_state('msg-4', 'failed', 'reason' => 'carrier error'))

    assert callback_fired
    assert_equal 'carrier error', msg.reason
  end

  def test_message_event_listener
    msg = SignalWire::Relay::Message.new(message_id: 'msg-5', state: 'queued')

    events = []
    msg.on_event { |e| events << e }
    msg._dispatch_event(message_state('msg-5', 'sent'))

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

  CREDENTIAL_ENV_VARS = %w[SIGNALWIRE_PROJECT_ID SIGNALWIRE_API_TOKEN SIGNALWIRE_SPACE].freeze

  # Clear the credential env vars for the block, restoring prior values after.
  def without_credential_env
    saved = CREDENTIAL_ENV_VARS.to_h { |k| [k, ENV.delete(k)] }
    yield
  ensure
    saved.each { |k, v| ENV[k] = v if v }
  end

  def test_client_requires_credentials
    require_relative '../lib/signalwire/relay/client'

    without_credential_env do
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new }
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new(project: 'proj', token: 'tok') }
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
