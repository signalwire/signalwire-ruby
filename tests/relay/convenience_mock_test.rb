# frozen_string_literal: true

# Real-mock-backed tests for the typed Call convenience wrappers restored in
# the Python reference (signalwire/relay/call.py):
#
#   play_tts / play_audio / play_silence / play_ringtone
#   detect_digit / detect_answering_machine / detect_fax
#   prompt_tts / prompt_audio
#   wait_for_answered / wait_for_ringing / wait_for_ending
#
# Each wrapper is a thin typed shim over an existing generic (#play,
# #detect, #play_and_collect, #wait_for) that builds the exact RELAY media /
# detect wire shape. These tests drive the real Ruby SDK against the shared
# porting-sdk mock_relay server and assert the *wire shape* that lands in the
# server journal -- NOT a transport mock. We dial a call through the mock
# (winner ends in `answered`), invoke the wrapper, then read back the
# `calling.play` / `calling.detect` / `calling.play_and_collect` frame and
# assert its media/detect payload.
#
# The wait_for_* tests assert the short-circuit contract: a call already at
# or past the target state returns immediately with a synthetic state event
# (matching Python's Call._wait_for_state), without any pushed event.

require 'minitest/autorun'
require 'securerandom'
require 'timeout'
require_relative 'mock_test'

# Shared fixture + dial/journal helpers for the Call-convenience mock tests.
module RelayConvenienceHelpers
  # Parallelize: per-client session scoping isolates each test's journal/scenarios.
  def self.included(base)
    base.parallelize_me!
  end

  def setup
    @handle = RelayMockTest.client
    @client = @handle[:client]
    @mock   = @handle[:mock]
  end

  def teardown
    RelayMockTest.shutdown_client(@handle) if @handle
  end

  def phone_device(to: '+15551112222', frm: '+15553334444')
    { 'type' => 'phone', 'params' => { 'to_number' => to, 'from_number' => frm } }
  end

  # Dial a single-leg call through the mock and return the resolved Call.
  # The winner ends in the requested final state (default `answered`).
  def dial_call(tag:, call_id:, states: %w[created answered])
    @mock.arm_dial(tag: tag, winner_call_id: call_id, states: states,
                   node_id: 'node-mock-1', device: phone_device)
    call = @client.dial([[phone_device]], tag: tag, dial_timeout: 5)

    assert_kind_of SignalWire::Relay::Call, call
    assert_equal call_id, call.call_id
    call
  end

  # Pull the single calling.<method> frame's params off the journal.
  def last_params(method)
    frames = @mock.journal_recv(method: method)

    refute_empty frames, "no #{method} frame in journal"
    frames.last.frame['params']
  end
end

class RelayCallConvenienceMockTest < Minitest::Test
  include RelayConvenienceHelpers

  # ---- play_tts --------------------------------------------------------

  def test_play_tts_builds_tts_media_with_all_fields
    call = dial_call(tag: 't-tts', call_id: 'C-TTS')
    action = call.play_tts('hello world', language: 'en-US', gender: 'female',
                                          voice: 'en-US-Standard-C', volume: 5.0)

    assert_instance_of SignalWire::Relay::PlayAction, action

    p = last_params('calling.play')

    assert_equal 'C-TTS', p['call_id']
    assert_tts_media(p['play'])
    # volume rides at the top level, not inside the media params.
    assert_in_delta(5.0, p['volume'])
    refute p['play'][0]['params'].key?('volume')
  end

  def assert_tts_media(media)
    assert_kind_of Array, media
    assert_equal 1, media.size
    assert_equal 'tts', media[0]['type']
    params = media[0]['params']

    assert_equal 'hello world',      params['text']
    assert_equal 'en-US',            params['language']
    assert_equal 'female',           params['gender']
    assert_equal 'en-US-Standard-C', params['voice']
  end

  def test_play_tts_omits_unset_optionals
    call = dial_call(tag: 't-tts2', call_id: 'C-TTS2')
    call.play_tts('just text')

    p = last_params('calling.play')
    params = p['play'][0]['params']

    assert_equal 'just text', params['text']
    refute params.key?('language'), 'language must be omitted when nil'
    refute params.key?('gender'),   'gender must be omitted when nil'
    refute params.key?('voice'),    'voice must be omitted when nil'
    refute p.key?('volume'),        'volume must be omitted when nil'
  end

  # ---- play_audio ------------------------------------------------------

  def test_play_audio_builds_audio_media
    call = dial_call(tag: 't-aud', call_id: 'C-AUD')
    call.play_audio('https://example.com/clip.wav', volume: 2.5)

    p = last_params('calling.play')
    media = p['play']

    assert_equal 'audio', media[0]['type']
    assert_equal 'https://example.com/clip.wav', media[0]['params']['url']
    assert_in_delta(2.5, p['volume'])
  end

  # ---- play_silence ----------------------------------------------------

  def test_play_silence_builds_silence_media
    call = dial_call(tag: 't-sil', call_id: 'C-SIL')
    call.play_silence(3.5)

    p = last_params('calling.play')
    media = p['play']

    assert_equal 'silence', media[0]['type']
    assert_in_delta(3.5, media[0]['params']['duration'])
    refute p.key?('volume'), 'silence takes no volume'
  end

  # ---- play_ringtone ---------------------------------------------------

  def test_play_ringtone_builds_ringtone_media_with_duration
    call = dial_call(tag: 't-rt', call_id: 'C-RT')
    call.play_ringtone('us', duration: 8.0, volume: 1.0)

    p = last_params('calling.play')
    media = p['play'][0]

    assert_equal 'ringtone', media['type']
    assert_equal 'us', media['params']['name']
    assert_in_delta(8.0, media['params']['duration'])
    assert_in_delta(1.0, p['volume'])
  end

  def test_play_ringtone_omits_duration_when_unset
    call = dial_call(tag: 't-rt2', call_id: 'C-RT2')
    call.play_ringtone('uk')

    p = last_params('calling.play')
    params = p['play'][0]['params']

    assert_equal 'uk', params['name']
    refute params.key?('duration'), 'duration omitted when nil'
  end
end

# detect_* / prompt_* / wait_for_* convenience wrappers. Split from the play_*
# tests to keep each class within budget.
class RelayCallDetectPromptMockTest < Minitest::Test
  include RelayConvenienceHelpers

  # ---- detect_digit ----------------------------------------------------

  def test_detect_digit_builds_digit_detector
    call = dial_call(tag: 't-dig', call_id: 'C-DIG')
    action = call.detect_digit(digits: '123', timeout: 10.0)

    assert_instance_of SignalWire::Relay::DetectAction, action

    p = last_params('calling.detect')

    assert_equal 'C-DIG', p['call_id']
    assert_equal 'digit', p['detect']['type']
    assert_equal '123',   p['detect']['params']['digits']
    assert_in_delta(10.0, p['timeout'])
  end

  def test_detect_digit_omits_digits_when_unset
    call = dial_call(tag: 't-dig2', call_id: 'C-DIG2')
    call.detect_digit

    p = last_params('calling.detect')

    assert_equal 'digit', p['detect']['type']
    assert_equal({}, p['detect']['params'])
    refute p.key?('timeout'), 'timeout omitted when nil'
  end

  # ---- detect_answering_machine ----------------------------------------

  MACHINE_DETECTOR_OPTS = {
    initial_timeout: 4.5, end_silence_timeout: 1.0, machine_voice_threshold: 1.25,
    machine_words_threshold: 6, detect_interruptions: false, detect_message_end: true,
    timeout: 30.0
  }.freeze

  def test_detect_answering_machine_builds_machine_detector_only_provided
    call = dial_call(tag: 't-amd', call_id: 'C-AMD')
    action = call.detect_answering_machine(**MACHINE_DETECTOR_OPTS)

    assert_instance_of SignalWire::Relay::DetectAction, action

    p = last_params('calling.detect')

    assert_equal 'machine', p['detect']['type']
    assert_machine_detector_params(p['detect']['params'])
    assert_in_delta(30.0, p['timeout'])
  end

  def assert_machine_detector_params(params)
    assert_in_delta(4.5, params['initial_timeout'])
    assert_in_delta(1.0, params['end_silence_timeout'])
    assert_in_delta(1.25, params['machine_voice_threshold'])
    assert_equal 6, params['machine_words_threshold']
    # Booleans must pass through even when false (nil-check, not truthiness).
    # assert_same keeps the exact-boolean check (true/false are singletons)
    # without Minitest/AssertTruthy/RefuteFalse weakening it to truthiness.
    assert_same false, params['detect_interruptions']
    assert_same true,  params['detect_message_end']
  end

  def test_detect_answering_machine_omits_all_unset
    call = dial_call(tag: 't-amd2', call_id: 'C-AMD2')
    call.detect_answering_machine

    p = last_params('calling.detect')

    assert_equal 'machine', p['detect']['type']
    assert_equal({}, p['detect']['params'], 'no params when nothing provided')
    refute p.key?('timeout')
  end

  # ---- detect_fax ------------------------------------------------------

  def test_detect_fax_builds_fax_detector
    call = dial_call(tag: 't-fax', call_id: 'C-FAX')
    action = call.detect_fax(tone: 'CED', timeout: 12.0)

    assert_instance_of SignalWire::Relay::DetectAction, action

    p = last_params('calling.detect')

    assert_equal 'fax', p['detect']['type']
    assert_equal 'CED', p['detect']['params']['tone']
    assert_in_delta(12.0, p['timeout'])
  end

  def test_detect_fax_omits_tone_when_unset
    call = dial_call(tag: 't-fax2', call_id: 'C-FAX2')
    call.detect_fax

    p = last_params('calling.detect')

    assert_equal 'fax', p['detect']['type']
    assert_equal({}, p['detect']['params'])
  end
end

# prompt_* + wait_for_* convenience wrappers. Split from the detect_* tests to
# keep each class within budget.
class RelayCallPromptWaitMockTest < Minitest::Test
  include RelayConvenienceHelpers

  # ---- prompt_tts ------------------------------------------------------

  def test_prompt_tts_builds_tts_media_and_collect
    collect = { 'digits' => { 'max' => 4 }, 'initial_timeout' => 5.0 }
    call = dial_call(tag: 't-ptts', call_id: 'C-PTTS')
    action = call.prompt_tts('enter your pin', collect, language: 'en-US',
                                                        voice: 'en-US-Wavenet-D', volume: 3.0)

    assert_instance_of SignalWire::Relay::CollectAction, action
    p = last_params('calling.play_and_collect')

    assert_equal 'C-PTTS', p['call_id']
    assert_equal 'tts', p['play'][0]['type']
    assert_prompt_tts_media(p['play'][0]['params'])
    assert_prompt_tts_collect(p)
  end

  def assert_prompt_tts_media(params)
    assert_equal 'enter your pin',  params['text']
    assert_equal 'en-US',           params['language']
    assert_equal 'en-US-Wavenet-D', params['voice']
  end

  # The collect object passes through verbatim; volume rides at top level.
  def assert_prompt_tts_collect(params)
    assert_equal 4, params['collect']['digits']['max']
    assert_in_delta(5.0, params['collect']['initial_timeout'])
    assert_in_delta(3.0, params['volume'])
  end

  # ---- prompt_audio ----------------------------------------------------

  def test_prompt_audio_builds_audio_media_and_collect
    collect = { 'speech' => { 'end_silence_timeout' => 1.0 } }
    call = dial_call(tag: 't-paud', call_id: 'C-PAUD')
    action = call.prompt_audio('https://example.com/ask.wav', collect, volume: 4.0)

    assert_instance_of SignalWire::Relay::CollectAction, action
    p = last_params('calling.play_and_collect')

    assert_prompt_audio_media(p['play'][0])
    assert_in_delta(1.0, p['collect']['speech']['end_silence_timeout'])
    assert_in_delta(4.0, p['volume'])
  end

  def assert_prompt_audio_media(media)
    assert_equal 'audio', media['type']
    assert_equal 'https://example.com/ask.wav', media['params']['url']
  end

  # ---- wait_for_* short-circuit ----------------------------------------
  #
  # A dialed call resolves in `answered`. Since created < ringing < answered
  # < ending < ended, waiting for `ringing` or `answered` must return
  # immediately (the call is already at/past the target) WITHOUT any pushed
  # event. We bound each with a tight Timeout to prove it doesn't block.

  def test_wait_for_answered_short_circuits_when_already_answered
    call = dial_call(tag: 't-wa', call_id: 'C-WA', states: %w[created answered])

    assert_equal 'answered', call.state
    event = Timeout.timeout(2) { call.wait_for_answered(timeout: 5) }

    refute_nil event, 'wait_for_answered should return immediately, not nil'
    assert_equal SignalWire::Relay::EVENT_CALL_STATE, event.event_type
    assert_equal 'answered', event.params['call_state']
  end

  def test_wait_for_ringing_short_circuits_when_past_ringing
    # Call is `answered`, which is past `ringing` -> immediate return.
    call = dial_call(tag: 't-wr', call_id: 'C-WR', states: %w[created answered])
    event = Timeout.timeout(2) { call.wait_for_ringing(timeout: 5) }

    refute_nil event
    assert_equal SignalWire::Relay::EVENT_CALL_STATE, event.event_type
    # Returns the *current* state (answered), not the target, per legacy SDK.
    assert_equal 'answered', event.params['call_state']
  end

  def test_wait_for_ending_short_circuits_when_already_ended
    # Drive the call to `ended` via a state event, then wait_for_ending must
    # return immediately because ended is past ending.
    call = dial_call(tag: 't-we', call_id: 'C-WE', states: %w[created answered])
    call._dispatch_event(
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'C-WE', 'call_state' => 'ended' }
    )

    assert_equal 'ended', call.state
    event = Timeout.timeout(2) { call.wait_for_ending(timeout: 5) }

    refute_nil event
    assert_equal SignalWire::Relay::EVENT_CALL_STATE, event.event_type
    assert_equal 'ended', event.params['call_state']
  end
end
