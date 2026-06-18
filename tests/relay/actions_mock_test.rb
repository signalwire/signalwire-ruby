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
  def setup
    RelayMockTest.reset
    @handle = RelayMockTest.client
    @client = @handle[:client]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
    RelayMockTest.reset
  end

  # ---- Helper: establish an answered inbound call ----------------------

  def answered_inbound_call(call_id = 'act-call-1')
    captured_q = Queue.new
    handler_done = Queue.new
    @client.on_call { |call| _capture_answered_call(call, captured_q, handler_done) }
    RelayMockTest.journal.inbound_call(call_id: call_id, auto_states: ['created'])
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
    RelayMockTest.journal.push({
                                 'jsonrpc' => '2.0', 'id' => SecureRandom.uuid, 'method' => 'signalwire.event',
                                 'params' => { 'event_type' => event_type, 'params' => params }
                               })
  end

  # Journaled outbound frames recorded for a RELAY method.
  def recv(method)
    RelayMockTest.journal.journal_recv(method: method)
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
    RelayMockTest.journal.arm_method('calling.play', [
                                       { 'emit' => { 'state' => 'playing' },  'delay_ms' => 1 },
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

  def test_play_on_completed_callback_fires
    call = answered_inbound_call('call-play-cb')
    RelayMockTest.journal.arm_method('calling.play', [{ 'emit' => { 'state' => 'finished' }, 'delay_ms' => 1 }])
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
    RelayMockTest.journal.arm_method('calling.record',
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
    RelayMockTest.journal.arm_method('calling.detect',
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
