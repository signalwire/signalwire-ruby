# frozen_string_literal: true

# Real-mock-backed tests for Action classes.
#
# Translated from
# signalwire-python/tests/unit/relay/test_actions_mock.py.
#
# For each major action (Play, Record, Detect, Collect, PlayAndCollect,
# Pay, Fax, Tap, Stream, Transcribe, AI), drive the SDK against the mock
# and assert the on-wire calling.<verb> frame, mock-pushed terminal events
# resolve action.wait, action.stop and friends journal the right
# sub-command frames, on_completed callbacks fire on terminal events, and
# the play_and_collect / detect gotchas are honoured.

require 'minitest/autorun'
require 'securerandom'
require 'timeout'
require_relative 'mock_test'

# Shared setup + answered-call helper for the action mock test groups below.
class RelayActionsTestBase < Minitest::Test
  # Parallelize: each test's client owns a distinct server session + scoped
  # harness, so action scenarios/journals never cross between concurrent tests.
  # Subclasses inherit this (Minitest's parallelize_me! defines a test_order
  # method, which subclasses inherit).
  parallelize_me!

  def setup
    @handle = RelayMockTest.client
    @client = @handle[:client]
    @mock   = @handle[:mock]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
  end

  # ---- Helper: establish an answered inbound call ----------------------

  def answered_inbound_call(call_id = 'act-call-1')
    captured_q = Queue.new
    handler_done = Queue.new
    @client.on_call(nil) { |call| _capture_answered_call(call, captured_q, handler_done) }
    @mock.inbound_call(call_id: call_id, auto_states: ['created'])
    Timeout.timeout(5) { handler_done.pop }
    call = Timeout.timeout(5) { captured_q.pop }
    # Mark answered so subsequent actions don't think it's gone.
    call.state = 'answered'
    call
  end

  def _capture_answered_call(call, captured_q, handler_done)
    captured_q.push(call)
    call.answer
    handler_done.push(true)
  end

  # Push a signalwire.event frame carrying a calling.* event onto the mock.
  def push_call_event(event_type, params)
    @mock.push({
                 'jsonrpc' => '2.0', 'id' => SecureRandom.uuid, 'method' => 'signalwire.event',
                 'params' => { 'event_type' => event_type, 'params' => params }
               })
  end

  # Journaled outbound frames recorded for a RELAY method.
  def recv(method)
    @mock.journal_recv(method: method)
  end
end

# ---- PlayAction ------------------------------------------------------
class RelayPlayActionTest < RelayActionsTestBase
  def test_play_journals_calling_play
    call = answered_inbound_call('call-play')
    call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hi' } }], control_id: 'play-ctl-1')
    plays = recv('calling.play')

    assert_equal 1, plays.size
    p = plays[0].frame['params']

    assert_equal 'call-play',  p['call_id']
    assert_equal 'play-ctl-1', p['control_id']
    assert_equal 'tts',        p['play'][0]['type']
  end

  def test_play_resolves_on_finished_event
    call = answered_inbound_call('call-play-fin')
    @mock.arm_method('calling.play', [
                       { 'emit' => { 'state' => 'playing' }, 'delay_ms' => 1 },
                       { 'emit' => { 'state' => 'finished' }, 'delay_ms' => 5 }
                     ])
    action = call.play([{ 'type' => 'silence', 'params' => { 'duration' => 1 } }], control_id: 'play-ctl-fin')

    assert_kind_of SignalWire::Relay::PlayAction, action
    event = action.wait(timeout: 5)

    assert_predicate action, :done?
    assert_equal 'finished', event.params['state']
  end

  def test_play_stop_journals_play_stop
    call = answered_inbound_call('call-play-stop')
    action = call.play([{ 'type' => 'silence', 'params' => { 'duration' => 60 } }], control_id: 'play-ctl-stop')
    action.stop
    stops = recv('calling.play.stop')

    refute_empty stops, 'no calling.play.stop frame'
    assert_equal 'play-ctl-stop', stops.last.frame['params']['control_id']
  end

  def test_play_pause_resume_volume_journal
    call = answered_inbound_call('call-play-prv')
    action = call.play([{ 'type' => 'silence', 'params' => { 'duration' => 60 } }], control_id: 'play-ctl-prv')
    action.pause
    action.resume
    action.volume(-3.0)

    refute_empty recv('calling.play.pause')
    refute_empty recv('calling.play.resume')
    vol = recv('calling.play.volume')

    refute_empty vol
    assert_in_delta(-3.0, vol.last.frame['params']['volume'])
  end

  def test_play_pause_forwards_optional_behavior
    call = answered_inbound_call('call-play-beh')
    action = call.play([{ 'type' => 'silence', 'params' => { 'duration' => 60 } }], control_id: 'play-ctl-beh')
    action.pause(behavior: 'stop')
    pauses = recv('calling.play.pause')

    refute_empty pauses
    assert_equal 'stop', pauses.last.frame['params']['behavior']
  end

  def test_play_on_completed_callback_fires
    call = answered_inbound_call('call-play-cb')
    @mock.arm_method('calling.play', [{ 'emit' => { 'state' => 'finished' }, 'delay_ms' => 1 }])
    cb_q = Queue.new
    cb = ->(event) { cb_q.push(event) }
    action = call.play([{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
                       control_id: 'play-ctl-cb', on_completed: cb)
    action.wait(timeout: 5)
    event = Timeout.timeout(2) { cb_q.pop }

    assert_equal 'finished', event.params['state']
  end
end

# ---- RecordAction ----------------------------------------------------
class RelayRecordActionTest < RelayActionsTestBase
  def test_record_journals_calling_record
    call = answered_inbound_call('call-rec')
    call.record(audio: { 'format' => 'mp3' }, control_id: 'rec-ctl-1')
    recs = recv('calling.record')

    assert_equal 1, recs.size
    p = recs[0].frame['params']

    assert_equal 'call-rec',  p['call_id']
    assert_equal 'rec-ctl-1', p['control_id']
    assert_equal 'mp3',       p['record']['audio']['format']
  end

  def test_record_resolves_on_finished_event
    call = answered_inbound_call('call-rec-fin')
    @mock.arm_method('calling.record',
                     [{ 'emit' => { 'state' => 'recording' }, 'delay_ms' => 1 },
                      { 'emit' => { 'state' => 'finished', 'url' => 'http://r.wav' },
                        'delay_ms' => 5 }])
    action = call.record(audio: { 'format' => 'wav' }, control_id: 'rec-ctl-fin')

    assert_kind_of SignalWire::Relay::RecordAction, action
    event = action.wait(timeout: 5)

    assert_equal 'finished', event.params['state']
  end

  def test_record_stop_journals_record_stop
    call = answered_inbound_call('call-rec-stop')
    action = call.record(audio: { 'format' => 'wav' }, control_id: 'rec-ctl-stop')
    action.stop
    stops = recv('calling.record.stop')

    refute_empty stops
    assert_equal 'rec-ctl-stop', stops.last.frame['params']['control_id']
  end
end

# ---- DetectAction ----------------------------------------------------
class RelayDetectActionTest < RelayActionsTestBase
  def test_detect_resolves_on_first_detect_payload
    call = answered_inbound_call('call-det')
    machine_detect = { 'detect' => { 'type' => 'machine', 'params' => { 'event' => 'MACHINE' } } }
    @mock.arm_method('calling.detect',
                     [{ 'emit' => machine_detect, 'delay_ms' => 1 },
                      { 'emit' => { 'state' => 'finished' }, 'delay_ms' => 10 }])
    action = call.detect({ 'type' => 'machine', 'params' => {} }, control_id: 'det-ctl-1')

    assert_kind_of SignalWire::Relay::DetectAction, action
    event = action.wait(timeout: 5)

    assert_equal 'machine', (event.params['detect'] || {})['type']
  end

  def test_detect_stop_journals_detect_stop
    call = answered_inbound_call('call-det-stop')
    action = call.detect({ 'type' => 'fax', 'params' => {} }, control_id: 'det-stop')
    action.stop
    stops = recv('calling.detect.stop')

    refute_empty stops
    assert_equal 'det-stop', stops.last.frame['params']['control_id']
  end
end

# ---- CollectAction (play_and_collect) --------------------------------
class RelayPlayAndCollectActionTest < RelayActionsTestBase
  def test_play_and_collect_journals_play_and_collect
    call = answered_inbound_call('call-pac')
    call.play_and_collect([{ 'type' => 'tts', 'params' => { 'text' => 'Press 1' } }],
                          { 'digits' => { 'max' => 1 } }, control_id: 'pac-ctl-1')
    pacs = recv('calling.play_and_collect')

    assert_equal 1, pacs.size
    p = pacs[0].frame['params']

    assert_equal 'call-pac', p['call_id']
    assert_equal 'tts', p.dig('play', 0, 'type')
    assert_equal 1, p.dig('collect', 'digits', 'max')
  end

  def test_play_and_collect_resolves_on_collect_event_only
    call = answered_inbound_call('call-pac-go')
    action = call.play_and_collect([{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
                                   { 'digits' => { 'max' => 1 } }, control_id: 'pac-go')

    assert_kind_of SignalWire::Relay::CollectAction, action
    _assert_play_finished_does_not_resolve(action)
    event = _push_collect_and_wait(action)

    assert_equal 'calling.call.collect', event.event_type
    assert_equal 'digit', (event.params['result'] || {})['type']
  end

  def _push_collect_and_wait(action)
    result = { 'type' => 'digit', 'params' => { 'digits' => '1' } }
    push_call_event('calling.call.collect',
                    'call_id' => 'call-pac-go', 'control_id' => 'pac-go', 'result' => result)
    action.wait(timeout: 2)
  end

  def _assert_play_finished_does_not_resolve(action)
    push_call_event('calling.call.play',
                    'call_id' => 'call-pac-go', 'control_id' => 'pac-go', 'state' => 'finished')
    sleep 0.1

    refute_predicate action, :done?,
                     'play_and_collect resolved on play(finished); should wait for collect'
  end

  def test_play_and_collect_stop_journals_pac_stop
    call = answered_inbound_call('call-pac-stop')
    action = call.play_and_collect([{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
                                   { 'digits' => { 'max' => 1 } }, control_id: 'pac-stop')
    action.stop
    stops = recv('calling.play_and_collect.stop')

    refute_empty stops
    assert_equal 'pac-stop', stops.last.frame['params']['control_id']
  end

  def test_play_and_collect_pause_resume_journal
    call = answered_inbound_call('call-pac-prv')
    action = call.play_and_collect([{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
                                   { 'digits' => { 'max' => 1 } }, control_id: 'pac-prv')
    action.pause(behavior: 'stop')
    action.resume

    pause_params = recv('calling.play_and_collect.pause').last&.frame&.dig('params')

    refute_nil pause_params, 'no calling.play_and_collect.pause frame'
    assert_equal 'pac-prv', pause_params['control_id']
    assert_equal 'stop', pause_params['behavior']
    refute_empty recv('calling.play_and_collect.resume'), 'no calling.play_and_collect.resume frame'
  end
end

# ---- Concrete-action control-method surface --------------------------
# The RELAY oracle projects Stoppable/Pausable/Volume onto the concrete
# actions. Assert each concrete action exposes exactly the control methods
# the reference declares (RecordAction has no volume; only Play/Collect are
# fully pausable+volume; the rest are stop-only).
class RelayActionControlSurfaceTest < Minitest::Test
  R = SignalWire::Relay

  def test_play_action_control_surface
    %i[stop pause resume volume].each do |m|
      assert R.const_get(:PlayAction).method_defined?(m), "PlayAction missing ##{m}"
    end
  end

  def test_collect_action_control_surface
    %i[stop pause resume volume start_input_timers].each do |m|
      assert R.const_get(:CollectAction).method_defined?(m), "CollectAction missing ##{m}"
    end
  end

  def test_record_action_is_pausable_but_not_volume
    %i[stop pause resume].each do |m|
      assert R.const_get(:RecordAction).method_defined?(m), "RecordAction missing ##{m}"
    end
    refute R.const_get(:RecordAction).method_defined?(:volume), 'RecordAction must not expose #volume'
  end

  def test_pause_accepts_optional_behavior
    %i[PlayAction RecordAction CollectAction].each do |cls|
      params = R.const_get(cls).instance_method(:pause).parameters

      assert_includes params, %i[key behavior], "#{cls}#pause must accept optional behavior: keyword"
    end
  end

  def test_stop_only_actions_are_not_pausable
    %i[DetectAction FaxAction TapAction StreamAction PayAction TranscribeAction AIAction
       StandaloneCollectAction].each do |cls|
      k = R.const_get(cls)

      assert k.method_defined?(:stop), "#{cls} missing #stop"
      refute k.method_defined?(:pause), "#{cls} must not be pausable"
      refute k.method_defined?(:volume), "#{cls} must not expose #volume"
    end
  end
end

# ---- StandaloneCollectAction -----------------------------------------
class RelayStandaloneCollectActionTest < RelayActionsTestBase
  def test_collect_journals_calling_collect
    call = answered_inbound_call('call-col')
    action = call.collect({ 'digits' => { 'max' => 4 } }, control_id: 'col-ctl')

    assert_kind_of SignalWire::Relay::StandaloneCollectAction, action
    cols = recv('calling.collect')

    assert_equal 1, cols.size
    p = cols[0].frame['params']

    assert_equal({ 'max' => 4 }, p['digits'])
    assert_equal 'col-ctl', p['control_id']
  end

  def test_collect_stop_journals_collect_stop
    call = answered_inbound_call('call-col-stop')
    action = call.collect({ 'digits' => { 'max' => 4 } }, control_id: 'col-stop')
    action.stop
    stops = recv('calling.collect.stop')

    refute_empty stops
    assert_equal 'col-stop', stops.last.frame['params']['control_id']
  end
end

# ---- PayAction -------------------------------------------------------
class RelayPayActionTest < RelayActionsTestBase
  def test_pay_journals_calling_pay
    call = answered_inbound_call('call-pay')
    call.pay(payment_connector_url: 'https://pay.example/connect', control_id: 'pay-ctl', charge_amount: '9.99')
    pays = recv('calling.pay')

    assert_equal 1, pays.size
    p = pays[0].frame['params']

    assert_equal 'https://pay.example/connect', p['payment_connector_url']
    assert_equal 'pay-ctl',                     p['control_id']
    assert_equal '9.99',                        p['charge_amount']
  end

  def test_pay_returns_pay_action
    call = answered_inbound_call('call-pay-act')
    action = call.pay(
      payment_connector_url: 'https://pay.example/connect',
      control_id: 'pay-act'
    )

    assert_kind_of SignalWire::Relay::PayAction, action
    assert_equal 'pay-act', action.control_id
  end

  def test_pay_stop_journals_pay_stop
    call = answered_inbound_call('call-pay-stop')
    action = call.pay(payment_connector_url: 'https://pay.example/connect', control_id: 'pay-stop')
    action.stop
    stops = recv('calling.pay.stop')

    refute_empty stops
    assert_equal 'pay-stop', stops.last.frame['params']['control_id']
  end
end

# ---- FaxAction -------------------------------------------------------
class RelayFaxActionTest < RelayActionsTestBase
  def test_send_fax_journals_calling_send_fax
    call = answered_inbound_call('call-sfax')
    call.send_fax(document: 'https://docs.example/test.pdf', identity: '+15551112222', control_id: 'sfax-ctl')
    faxes = recv('calling.send_fax')

    assert_equal 1, faxes.size
    p = faxes[0].frame['params']

    assert_equal 'https://docs.example/test.pdf', p['document']
    assert_equal '+15551112222',                  p['identity']
    assert_equal 'sfax-ctl',                      p['control_id']
  end

  def test_receive_fax_returns_fax_action
    call = answered_inbound_call('call-rfax')
    action = call.receive_fax(control_id: 'rfax-ctl')

    assert_kind_of SignalWire::Relay::FaxAction, action
  end
end

# ---- TapAction -------------------------------------------------------
class RelayTapActionTest < RelayActionsTestBase
  def test_tap_journals_calling_tap
    call = answered_inbound_call('call-tap')
    tap_opts = { 'type' => 'audio', 'params' => { 'direction' => 'both' } }
    device = { 'type' => 'rtp', 'params' => { 'addr' => '203.0.113.1', 'port' => 4000 } }
    call.tap_audio(tap_opts, device: device, control_id: 'tap-ctl')
    p = recv('calling.tap').first.frame['params']

    assert_equal tap_opts, p['tap']
    assert_equal 4000, p.dig('device', 'params', 'port')
    assert_equal 'tap-ctl', p['control_id']
  end

  def test_tap_stop_journals_tap_stop
    call = answered_inbound_call('call-tap-stop')
    tap_opts = { 'type' => 'audio', 'params' => { 'direction' => 'both' } }
    device = { 'type' => 'rtp', 'params' => { 'addr' => '203.0.113.1', 'port' => 4000 } }
    action = call.tap_audio(tap_opts, device: device, control_id: 'tap-stop')

    assert_kind_of SignalWire::Relay::TapAction, action
    action.stop
    stops = recv('calling.tap.stop')

    refute_empty stops
    assert_equal 'tap-stop', stops.last.frame['params']['control_id']
  end
end

# ---- StreamAction ----------------------------------------------------
class RelayStreamActionTest < RelayActionsTestBase
  def test_stream_journals_calling_stream
    call = answered_inbound_call('call-strm')
    call.stream(url: 'wss://stream.example/audio', codec: 'OPUS@48000h', control_id: 'strm-ctl')
    strs = recv('calling.stream')

    assert_equal 1, strs.size
    p = strs[0].frame['params']

    assert_equal 'wss://stream.example/audio', p['url']
    assert_equal 'OPUS@48000h',                p['codec']
    assert_equal 'strm-ctl',                   p['control_id']
  end

  def test_stream_stop_journals_stream_stop
    call = answered_inbound_call('call-strm-stop')
    action = call.stream(url: 'wss://stream.example/audio', control_id: 'strm-stop')

    assert_kind_of SignalWire::Relay::StreamAction, action
    action.stop
    stops = recv('calling.stream.stop')

    refute_empty stops
    assert_equal 'strm-stop', stops.last.frame['params']['control_id']
  end
end

# ---- TranscribeAction ------------------------------------------------
class RelayTranscribeActionTest < RelayActionsTestBase
  def test_transcribe_journals_calling_transcribe
    call = answered_inbound_call('call-tr')
    action = call.transcribe(control_id: 'tr-ctl')

    assert_kind_of SignalWire::Relay::TranscribeAction, action
    trs = recv('calling.transcribe')

    assert_equal 1, trs.size
    assert_equal 'tr-ctl', trs[0].frame['params']['control_id']
  end

  def test_transcribe_stop_journals_transcribe_stop
    call = answered_inbound_call('call-tr-stop')
    action = call.transcribe(control_id: 'tr-stop')
    action.stop
    stops = recv('calling.transcribe.stop')

    refute_empty stops
    assert_equal 'tr-stop', stops.last.frame['params']['control_id']
  end
end

# ---- AIAction --------------------------------------------------------
class RelayAIActionTest < RelayActionsTestBase
  def test_ai_journals_calling_ai
    call = answered_inbound_call('call-ai')
    action = call.ai(prompt: { 'text' => 'You are helpful.' }, control_id: 'ai-ctl')

    assert_kind_of SignalWire::Relay::AIAction, action
    ais = recv('calling.ai')

    assert_equal 1, ais.size
    p = ais[0].frame['params']

    assert_equal({ 'text' => 'You are helpful.' }, p['prompt'])
    assert_equal 'ai-ctl', p['control_id']
  end

  def test_ai_stop_journals_ai_stop
    call = answered_inbound_call('call-ai-stop')
    action = call.ai(prompt: { 'text' => 'You are helpful.' }, control_id: 'ai-stop')
    action.stop
    stops = recv('calling.ai.stop')

    refute_empty stops
    assert_equal 'ai-stop', stops.last.frame['params']['control_id']
  end
end

# ---- Concurrent actions, control_id correlation ----------------------
class RelayConcurrentActionsTest < RelayActionsTestBase
  def test_concurrent_play_and_record_route_independently
    call = answered_inbound_call('call-multi')
    play_action = call.play([{ 'type' => 'silence', 'params' => { 'duration' => 60 } }], control_id: 'ctl-play-x')
    record_action = call.record(audio: { 'format' => 'wav' }, control_id: 'ctl-rec-y')

    assert_equal 'ctl-play-x', play_action.control_id
    assert_equal 'ctl-rec-y',  record_action.control_id

    push_call_event('calling.call.play',
                    'call_id' => 'call-multi', 'control_id' => 'ctl-play-x', 'state' => 'finished')
    play_action.wait(timeout: 2)

    assert_predicate play_action, :done?
    refute_predicate record_action, :done?
  end
end

# ---- API-name -> wire-key REMAP pins ---------------------------------
#
# The reference exposes seven keyword parameters in signalwire/relay/call.py
# under one API name but puts them on the wire under a DIFFERENT key:
#
#   play()             media        -> "play"
#   play_and_collect() media        -> "play"
#   pay()              input_method -> "input"
#   join_conference()  stream_obj   -> "stream"
#   bind_digit()       bind_params  -> "params"
#   ai()               ai_params    -> "params"
#   amazon_bedrock()   ai_params    -> "params"
#
# Every construction-level test passes even when a port sends the WRONG key,
# so each remap needs a wire-level assertion on the emitted frame. Ruby names
# `media` positionally on #play / #play_and_collect and re-keys it to "play"
# at the emitter; the other five ride the verbatim `**kwargs` bag, whose keys
# are stringified unchanged — the wire key is a legal bag key at every site
# (no collision with a Ruby parameter name), so each is reachable by writing
# the wire key directly. These tests pin that reachability on the wire.
class RelayRemapWireKeyTest < RelayActionsTestBase
  def test_play_media_lands_under_play_key
    call = answered_inbound_call('call-remap-play')
    call.play([{ 'type' => 'tts', 'params' => { 'text' => 'hi' } }], control_id: 'remap-play')
    p = recv('calling.play').last.frame['params']

    assert_equal 'tts', p.dig('play', 0, 'type')
    assert_nil p['media'], 'media must not appear on the wire; the key is "play"'
  end

  def test_play_and_collect_media_lands_under_play_key
    call = answered_inbound_call('call-remap-pac')
    call.play_and_collect([{ 'type' => 'tts', 'params' => { 'text' => 'Press 1' } }],
                          { 'digits' => { 'max' => 1 } }, control_id: 'remap-pac')
    p = recv('calling.play_and_collect').last.frame['params']

    assert_equal 'tts', p.dig('play', 0, 'type')
    assert_nil p['media'], 'media must not appear on the wire; the key is "play"'
  end

  def test_pay_input_method_lands_under_input_key
    call = answered_inbound_call('call-remap-pay')
    call.pay(payment_connector_url: 'https://pay.example/connect',
             control_id: 'remap-pay', input: 'dtmf')
    p = recv('calling.pay').last.frame['params']

    assert_equal 'dtmf', p['input'], 'pay input_method must ride the wire key "input"'
    assert_nil p['input_method'], 'input_method is the API name, not the wire key'
  end

  def test_join_conference_stream_obj_lands_under_stream_key
    call = answered_inbound_call('call-remap-conf')
    stream = { 'url' => 'wss://stream.example/live' }
    call.join_conference(name: 'remap-conf', stream: stream)
    p = recv('calling.join_conference').last.frame['params']

    assert_equal 'remap-conf', p['name']
    assert_equal stream, p['stream'], 'join_conference stream_obj must ride the wire key "stream"'
    assert_nil p['stream_obj'], 'stream_obj is the API name, not the wire key'
  end

  def test_bind_digit_bind_params_lands_under_params_key
    call = answered_inbound_call('call-remap-bind')
    bind_params = { 'realm' => 'demo', 'foo' => 'bar' }
    call.bind_digit(digits: '123', bind_method: 'calling.play', params: bind_params)
    p = recv('calling.bind_digit').last.frame['params']

    assert_equal '123', p['digits']
    assert_equal 'calling.play', p['bind_method']
    assert_equal bind_params, p['params'], 'bind_digit bind_params must ride the wire key "params"'
    assert_nil p['bind_params'], 'bind_params is the API name, not the wire key'
  end

  def test_ai_ai_params_lands_under_params_key
    call = answered_inbound_call('call-remap-ai')
    ai_params = { 'temperature' => 0.7 }
    call.ai(prompt: { 'text' => 'You are helpful.' }, control_id: 'remap-ai', params: ai_params)
    p = recv('calling.ai').last.frame['params']

    assert_equal({ 'text' => 'You are helpful.' }, p['prompt'])
    assert_equal ai_params, p['params'], 'ai ai_params must ride the wire key "params"'
    assert_nil p['ai_params'], 'ai_params is the API name, not the wire key'
  end

  def test_amazon_bedrock_ai_params_lands_under_params_key
    call = answered_inbound_call('call-remap-bedrock')
    ai_params = { 'model' => 'anthropic.claude' }
    call.amazon_bedrock(prompt: { 'text' => 'You are helpful.' }, params: ai_params)
    p = recv('calling.amazon_bedrock').last.frame['params']

    assert_equal({ 'text' => 'You are helpful.' }, p['prompt'])
    assert_equal ai_params, p['params'], 'amazon_bedrock ai_params must ride the wire key "params"'
    assert_nil p['ai_params'], 'ai_params is the API name, not the wire key'
  end
end
