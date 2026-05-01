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

class RelayActionsMockTest < Minitest::Test
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
    @client.on_call do |call|
      captured_q.push(call)
      call.answer
      handler_done.push(true)
    end
    RelayMockTest.journal.inbound_call(call_id: call_id, auto_states: ['created'])
    Timeout.timeout(5) { handler_done.pop }
    call = Timeout.timeout(5) { captured_q.pop }
    # Mark answered so subsequent actions don't think it's gone.
    call.state = 'answered'
    call
  end

  # ---- PlayAction ------------------------------------------------------

  def test_play_journals_calling_play
    call = answered_inbound_call('call-play')
    call.play(
      [{ 'type' => 'tts', 'params' => { 'text' => 'hi' } }],
      control_id: 'play-ctl-1',
    )
    plays = RelayMockTest.journal.journal_recv(method: 'calling.play')
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
      { 'emit' => { 'state' => 'finished' }, 'delay_ms' => 5 },
    ])
    action = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
      control_id: 'play-ctl-fin',
    )
    assert_kind_of SignalWire::Relay::PlayAction, action
    event = action.wait(timeout: 5)
    assert action.done?
    assert_equal 'finished', event.params['state']
  end

  def test_play_stop_journals_play_stop
    call = answered_inbound_call('call-play-stop')
    action = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 60 } }],
      control_id: 'play-ctl-stop',
    )
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.play.stop')
    refute_empty stops, 'no calling.play.stop frame'
    assert_equal 'play-ctl-stop', stops.last.frame['params']['control_id']
  end

  def test_play_pause_resume_volume_journal
    call = answered_inbound_call('call-play-prv')
    action = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 60 } }],
      control_id: 'play-ctl-prv',
    )
    action.pause
    action.resume
    action.volume(-3.0)
    refute_empty RelayMockTest.journal.journal_recv(method: 'calling.play.pause')
    refute_empty RelayMockTest.journal.journal_recv(method: 'calling.play.resume')
    vol = RelayMockTest.journal.journal_recv(method: 'calling.play.volume')
    refute_empty vol
    assert_equal(-3.0, vol.last.frame['params']['volume'])
  end

  def test_play_on_completed_callback_fires
    call = answered_inbound_call('call-play-cb')
    RelayMockTest.journal.arm_method('calling.play', [
      { 'emit' => { 'state' => 'finished' }, 'delay_ms' => 1 },
    ])
    cb_q = Queue.new
    cb = ->(event) { cb_q.push(event) }
    action = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
      control_id:   'play-ctl-cb',
      on_completed: cb,
    )
    action.wait(timeout: 5)
    event = Timeout.timeout(2) { cb_q.pop }
    assert_equal 'finished', event.params['state']
  end

  # ---- RecordAction ----------------------------------------------------

  def test_record_journals_calling_record
    call = answered_inbound_call('call-rec')
    call.record(audio: { 'format' => 'mp3' }, control_id: 'rec-ctl-1')
    recs = RelayMockTest.journal.journal_recv(method: 'calling.record')
    assert_equal 1, recs.size
    p = recs[0].frame['params']
    assert_equal 'call-rec',  p['call_id']
    assert_equal 'rec-ctl-1', p['control_id']
    assert_equal 'mp3',       p['record']['audio']['format']
  end

  def test_record_resolves_on_finished_event
    call = answered_inbound_call('call-rec-fin')
    RelayMockTest.journal.arm_method('calling.record', [
      { 'emit' => { 'state' => 'recording' }, 'delay_ms' => 1 },
      { 'emit' => { 'state' => 'finished', 'url' => 'http://r.wav' },
        'delay_ms' => 5 },
    ])
    action = call.record(audio: { 'format' => 'wav' }, control_id: 'rec-ctl-fin')
    assert_kind_of SignalWire::Relay::RecordAction, action
    event = action.wait(timeout: 5)
    assert_equal 'finished', event.params['state']
  end

  def test_record_stop_journals_record_stop
    call = answered_inbound_call('call-rec-stop')
    action = call.record(audio: { 'format' => 'wav' },
                         control_id: 'rec-ctl-stop')
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.record.stop')
    refute_empty stops
    assert_equal 'rec-ctl-stop', stops.last.frame['params']['control_id']
  end

  # ---- DetectAction ----------------------------------------------------

  def test_detect_resolves_on_first_detect_payload
    call = answered_inbound_call('call-det')
    RelayMockTest.journal.arm_method('calling.detect', [
      {
        'emit' => {
          'detect' => { 'type' => 'machine', 'params' => { 'event' => 'MACHINE' } },
        },
        'delay_ms' => 1,
      },
      { 'emit' => { 'state' => 'finished' }, 'delay_ms' => 10 },
    ])
    action = call.detect(
      { 'type' => 'machine', 'params' => {} },
      control_id: 'det-ctl-1',
    )
    assert_kind_of SignalWire::Relay::DetectAction, action
    event = action.wait(timeout: 5)
    assert_equal 'machine', (event.params['detect'] || {})['type']
  end

  def test_detect_stop_journals_detect_stop
    call = answered_inbound_call('call-det-stop')
    action = call.detect(
      { 'type' => 'fax', 'params' => {} },
      control_id: 'det-stop',
    )
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.detect.stop')
    refute_empty stops
    assert_equal 'det-stop', stops.last.frame['params']['control_id']
  end

  # ---- CollectAction (play_and_collect) --------------------------------

  def test_play_and_collect_journals_play_and_collect
    call = answered_inbound_call('call-pac')
    call.play_and_collect(
      [{ 'type' => 'tts', 'params' => { 'text' => 'Press 1' } }],
      { 'digits' => { 'max' => 1 } },
      control_id: 'pac-ctl-1',
    )
    pacs = RelayMockTest.journal.journal_recv(method: 'calling.play_and_collect')
    assert_equal 1, pacs.size
    p = pacs[0].frame['params']
    assert_equal 'call-pac', p['call_id']
    assert_equal 'tts',      p['play'][0]['type']
    assert_equal 1,          p['collect']['digits']['max']
  end

  def test_play_and_collect_resolves_on_collect_event_only
    call = answered_inbound_call('call-pac-go')
    action = call.play_and_collect(
      [{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
      { 'digits' => { 'max' => 1 } },
      control_id: 'pac-go',
    )
    assert_kind_of SignalWire::Relay::CollectAction, action

    # Push a play(finished) -- MUST NOT resolve.
    RelayMockTest.journal.push({
      'jsonrpc' => '2.0',
      'id'      => SecureRandom.uuid,
      'method'  => 'signalwire.event',
      'params'  => {
        'event_type' => 'calling.call.play',
        'params'     => {
          'call_id'    => 'call-pac-go',
          'control_id' => 'pac-go',
          'state'      => 'finished',
        },
      },
    })
    sleep 0.1
    refute action.done?,
           'play_and_collect resolved on play(finished); should wait for collect'

    # Now push the collect event -- action resolves.
    RelayMockTest.journal.push({
      'jsonrpc' => '2.0',
      'id'      => SecureRandom.uuid,
      'method'  => 'signalwire.event',
      'params'  => {
        'event_type' => 'calling.call.collect',
        'params'     => {
          'call_id'    => 'call-pac-go',
          'control_id' => 'pac-go',
          'result'     => { 'type' => 'digit', 'params' => { 'digits' => '1' } },
        },
      },
    })
    event = action.wait(timeout: 2)
    assert_equal 'calling.call.collect', event.event_type
    result = event.params['result'] || {}
    assert_equal 'digit', result['type']
  end

  def test_play_and_collect_stop_journals_pac_stop
    call = answered_inbound_call('call-pac-stop')
    action = call.play_and_collect(
      [{ 'type' => 'silence', 'params' => { 'duration' => 1 } }],
      { 'digits' => { 'max' => 1 } },
      control_id: 'pac-stop',
    )
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.play_and_collect.stop')
    refute_empty stops
    assert_equal 'pac-stop', stops.last.frame['params']['control_id']
  end

  # ---- StandaloneCollectAction -----------------------------------------

  def test_collect_journals_calling_collect
    call = answered_inbound_call('call-col')
    action = call.collect(
      { 'digits' => { 'max' => 4 } },
      control_id: 'col-ctl',
    )
    assert_kind_of SignalWire::Relay::StandaloneCollectAction, action
    cols = RelayMockTest.journal.journal_recv(method: 'calling.collect')
    assert_equal 1, cols.size
    p = cols[0].frame['params']
    assert_equal({ 'max' => 4 }, p['digits'])
    assert_equal 'col-ctl',     p['control_id']
  end

  def test_collect_stop_journals_collect_stop
    call = answered_inbound_call('call-col-stop')
    action = call.collect(
      { 'digits' => { 'max' => 4 } },
      control_id: 'col-stop',
    )
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.collect.stop')
    refute_empty stops
    assert_equal 'col-stop', stops.last.frame['params']['control_id']
  end

  # ---- PayAction -------------------------------------------------------

  def test_pay_journals_calling_pay
    call = answered_inbound_call('call-pay')
    call.pay(
      payment_connector_url: 'https://pay.example/connect',
      control_id:            'pay-ctl',
      charge_amount:         '9.99',
    )
    pays = RelayMockTest.journal.journal_recv(method: 'calling.pay')
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
      control_id:            'pay-act',
    )
    assert_kind_of SignalWire::Relay::PayAction, action
    assert_equal 'pay-act', action.control_id
  end

  def test_pay_stop_journals_pay_stop
    call = answered_inbound_call('call-pay-stop')
    action = call.pay(
      payment_connector_url: 'https://pay.example/connect',
      control_id:            'pay-stop',
    )
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.pay.stop')
    refute_empty stops
    assert_equal 'pay-stop', stops.last.frame['params']['control_id']
  end

  # ---- FaxAction -------------------------------------------------------

  def test_send_fax_journals_calling_send_fax
    call = answered_inbound_call('call-sfax')
    call.send_fax(
      document:   'https://docs.example/test.pdf',
      identity:   '+15551112222',
      control_id: 'sfax-ctl',
    )
    faxes = RelayMockTest.journal.journal_recv(method: 'calling.send_fax')
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

  # ---- TapAction -------------------------------------------------------

  def test_tap_journals_calling_tap
    call = answered_inbound_call('call-tap')
    tap_opts = { 'type' => 'audio', 'params' => { 'direction' => 'both' } }
    call.tap_audio(
      tap_opts,
      device:     { 'type' => 'rtp',
                    'params' => { 'addr' => '203.0.113.1', 'port' => 4000 } },
      control_id: 'tap-ctl',
    )
    taps = RelayMockTest.journal.journal_recv(method: 'calling.tap')
    assert_equal 1, taps.size
    p = taps[0].frame['params']
    assert_equal tap_opts,  p['tap']
    assert_equal 4000,      p['device']['params']['port']
    assert_equal 'tap-ctl', p['control_id']
  end

  def test_tap_stop_journals_tap_stop
    call = answered_inbound_call('call-tap-stop')
    tap_opts = { 'type' => 'audio', 'params' => { 'direction' => 'both' } }
    action = call.tap_audio(
      tap_opts,
      device:     { 'type' => 'rtp',
                    'params' => { 'addr' => '203.0.113.1', 'port' => 4000 } },
      control_id: 'tap-stop',
    )
    assert_kind_of SignalWire::Relay::TapAction, action
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.tap.stop')
    refute_empty stops
    assert_equal 'tap-stop', stops.last.frame['params']['control_id']
  end

  # ---- StreamAction ----------------------------------------------------

  def test_stream_journals_calling_stream
    call = answered_inbound_call('call-strm')
    call.stream(
      url:        'wss://stream.example/audio',
      codec:      'OPUS@48000h',
      control_id: 'strm-ctl',
    )
    strs = RelayMockTest.journal.journal_recv(method: 'calling.stream')
    assert_equal 1, strs.size
    p = strs[0].frame['params']
    assert_equal 'wss://stream.example/audio', p['url']
    assert_equal 'OPUS@48000h',                p['codec']
    assert_equal 'strm-ctl',                   p['control_id']
  end

  def test_stream_stop_journals_stream_stop
    call = answered_inbound_call('call-strm-stop')
    action = call.stream(
      url:        'wss://stream.example/audio',
      control_id: 'strm-stop',
    )
    assert_kind_of SignalWire::Relay::StreamAction, action
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.stream.stop')
    refute_empty stops
    assert_equal 'strm-stop', stops.last.frame['params']['control_id']
  end

  # ---- TranscribeAction ------------------------------------------------

  def test_transcribe_journals_calling_transcribe
    call = answered_inbound_call('call-tr')
    action = call.transcribe(control_id: 'tr-ctl')
    assert_kind_of SignalWire::Relay::TranscribeAction, action
    trs = RelayMockTest.journal.journal_recv(method: 'calling.transcribe')
    assert_equal 1, trs.size
    assert_equal 'tr-ctl', trs[0].frame['params']['control_id']
  end

  def test_transcribe_stop_journals_transcribe_stop
    call = answered_inbound_call('call-tr-stop')
    action = call.transcribe(control_id: 'tr-stop')
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.transcribe.stop')
    refute_empty stops
    assert_equal 'tr-stop', stops.last.frame['params']['control_id']
  end

  # ---- AIAction --------------------------------------------------------

  def test_ai_journals_calling_ai
    call = answered_inbound_call('call-ai')
    action = call.ai(
      prompt:     { 'text' => 'You are helpful.' },
      control_id: 'ai-ctl',
    )
    assert_kind_of SignalWire::Relay::AIAction, action
    ais = RelayMockTest.journal.journal_recv(method: 'calling.ai')
    assert_equal 1, ais.size
    p = ais[0].frame['params']
    assert_equal({ 'text' => 'You are helpful.' }, p['prompt'])
    assert_equal 'ai-ctl', p['control_id']
  end

  def test_ai_stop_journals_ai_stop
    call = answered_inbound_call('call-ai-stop')
    action = call.ai(
      prompt:     { 'text' => 'You are helpful.' },
      control_id: 'ai-stop',
    )
    action.stop
    stops = RelayMockTest.journal.journal_recv(method: 'calling.ai.stop')
    refute_empty stops
    assert_equal 'ai-stop', stops.last.frame['params']['control_id']
  end

  # ---- Concurrent actions, control_id correlation ----------------------

  def test_concurrent_play_and_record_route_independently
    call = answered_inbound_call('call-multi')
    play_action = call.play(
      [{ 'type' => 'silence', 'params' => { 'duration' => 60 } }],
      control_id: 'ctl-play-x',
    )
    record_action = call.record(audio: { 'format' => 'wav' },
                                 control_id: 'ctl-rec-y')
    assert_equal 'ctl-play-x', play_action.control_id
    assert_equal 'ctl-rec-y',  record_action.control_id

    RelayMockTest.journal.push({
      'jsonrpc' => '2.0',
      'id'      => SecureRandom.uuid,
      'method'  => 'signalwire.event',
      'params'  => {
        'event_type' => 'calling.call.play',
        'params'     => {
          'call_id'    => 'call-multi',
          'control_id' => 'ctl-play-x',
          'state'      => 'finished',
        },
      },
    })
    play_action.wait(timeout: 2)
    assert play_action.done?
    refute record_action.done?
  end
end
