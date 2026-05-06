# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_calling_mock.py.
#
# Every command in CallingNamespace is exercised here with the real Ruby
# RestClient wired to the in-process mock_signalwire server. Each test:
#
# 1. Calls the SDK method (no transport patching).
# 2. Asserts on the response body shape that the mock returns from the spec.
# 3. Asserts on MockTest.journal.last so we know the SDK sent the right
#    wire request — method, path, command field, and (where applicable)
#    the id and any keyword params.

require 'minitest/autorun'
require_relative 'mock_test'

class CallingMockTest < Minitest::Test
  CALLS_PATH = '/api/calling/calls'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # -------------------------------------------------------------------
  # Lifecycle commands
  # -------------------------------------------------------------------

  def test_dial_forwards_codecs_array
    body = @client.calling.dial(
      url: 'https://example.com/swml',
      to: '+15551234567',
      codecs: %w[OPUS G729 VP8 PCMA],
    )
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'dial', last.body['command']
    refute last.body.key?('id')
    assert_equal %w[OPUS G729 VP8 PCMA], last.body['params']['codecs']
    assert_equal '+15551234567', last.body['params']['to']
  end

  def test_dial_forwards_codecs_string
    body = @client.calling.dial(
      url: 'https://example.com/swml',
      to: '+15551234567',
      codecs: 'OPUS,G729,VP8,PCMA',
    )
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'dial', last.body['command']
    assert_equal 'OPUS,G729,VP8,PCMA', last.body['params']['codecs']
  end

  def test_update
    body = @client.calling.update(id: 'call-1', state: 'hold')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    refute_nil last.matched_route
    assert_equal 'update', last.body['command']
    refute last.body.key?('id')
    assert_equal 'call-1', last.body['params']['id']
    assert_equal 'hold', last.body['params']['state']
  end

  def test_transfer
    body = @client.calling.transfer(
      'call-123', destination: '+15551234567', from_number: '+15559876543',
    )
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.transfer', last.body['command']
    assert_equal 'call-123', last.body['id']
    assert_equal '+15551234567', last.body['params']['destination']
    assert_equal '+15559876543', last.body['params']['from_number']
  end

  def test_disconnect
    body = @client.calling.disconnect('call-456', reason: 'busy')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.disconnect', last.body['command']
    assert_equal 'call-456', last.body['id']
    assert_equal 'busy', last.body['params']['reason']
  end

  # -------------------------------------------------------------------
  # Play commands
  # -------------------------------------------------------------------

  def test_play_pause
    body = @client.calling.play_pause('call-1', control_id: 'ctrl-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.play.pause', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'ctrl-1', last.body['params']['control_id']
  end

  def test_play_resume
    body = @client.calling.play_resume('call-1', control_id: 'ctrl-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.play.resume', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'ctrl-1', last.body['params']['control_id']
  end

  def test_play_stop
    body = @client.calling.play_stop('call-1', control_id: 'ctrl-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.play.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'ctrl-1', last.body['params']['control_id']
  end

  def test_play_volume
    body = @client.calling.play_volume('call-1', control_id: 'ctrl-1', volume: 2.5)
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.play.volume', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_in_delta 2.5, last.body['params']['volume'], 0.0001
  end

  # -------------------------------------------------------------------
  # Record commands
  # -------------------------------------------------------------------

  def test_record
    body = @client.calling.record('call-1', record: { 'format' => 'mp3' })
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.record', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal({ 'format' => 'mp3' }, last.body['params']['record'])
  end

  def test_record_pause
    body = @client.calling.record_pause('call-1', control_id: 'rec-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.record.pause', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'rec-1', last.body['params']['control_id']
  end

  def test_record_resume
    body = @client.calling.record_resume('call-1', control_id: 'rec-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.record.resume', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'rec-1', last.body['params']['control_id']
  end

  # -------------------------------------------------------------------
  # Collect commands
  # -------------------------------------------------------------------

  def test_collect
    body = @client.calling.collect('call-1', initial_timeout: 5, digits: { 'max' => 4 })
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.collect', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 5, last.body['params']['initial_timeout']
  end

  def test_collect_stop
    body = @client.calling.collect_stop('call-1', control_id: 'col-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.collect.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'col-1', last.body['params']['control_id']
  end

  def test_collect_start_input_timers
    body = @client.calling.collect_start_input_timers('call-1', control_id: 'col-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.collect.start_input_timers', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'col-1', last.body['params']['control_id']
  end

  # -------------------------------------------------------------------
  # Detect / tap / stream / denoise / transcribe
  # -------------------------------------------------------------------

  def test_detect
    body = @client.calling.detect('call-1', detect: { 'type' => 'machine', 'params' => {} })
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.detect', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'machine', last.body['params']['detect']['type']
  end

  def test_detect_stop
    body = @client.calling.detect_stop('call-1', control_id: 'det-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.detect.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'det-1', last.body['params']['control_id']
  end

  def test_tap
    body = @client.calling.tap(
      'call-1', tap: { 'type' => 'audio' }, device: { 'type' => 'rtp' },
    )
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.tap', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal({ 'type' => 'audio' }, last.body['params']['tap'])
  end

  def test_tap_stop
    body = @client.calling.tap_stop('call-1', control_id: 'tap-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.tap.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'tap-1', last.body['params']['control_id']
  end

  def test_stream
    body = @client.calling.stream('call-1', url: 'wss://example.com/audio')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.stream', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'wss://example.com/audio', last.body['params']['url']
  end

  def test_stream_stop
    body = @client.calling.stream_stop('call-1', control_id: 'stream-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.stream.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'stream-1', last.body['params']['control_id']
  end

  def test_denoise
    body = @client.calling.denoise('call-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.denoise', last.body['command']
    assert_equal 'call-1', last.body['id']
  end

  def test_denoise_stop
    body = @client.calling.denoise_stop('call-1', control_id: 'dn-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.denoise.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'dn-1', last.body['params']['control_id']
  end

  def test_transcribe
    body = @client.calling.transcribe(
      'call-1', language: 'en-US', transcribe: { 'engine' => 'google' },
    )
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.transcribe', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'en-US', last.body['params']['language']
  end

  def test_transcribe_stop
    body = @client.calling.transcribe_stop('call-1', control_id: 'tr-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.transcribe.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'tr-1', last.body['params']['control_id']
  end

  # -------------------------------------------------------------------
  # AI commands
  # -------------------------------------------------------------------

  def test_ai_hold
    body = @client.calling.ai_hold('call-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.ai_hold', last.body['command']
    assert_equal 'call-1', last.body['id']
  end

  def test_ai_unhold
    body = @client.calling.ai_unhold('call-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.ai_unhold', last.body['command']
    assert_equal 'call-1', last.body['id']
  end

  def test_ai_stop
    body = @client.calling.ai_stop('call-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.ai.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
  end

  # -------------------------------------------------------------------
  # Live transcribe / translate
  # -------------------------------------------------------------------

  def test_live_transcribe
    body = @client.calling.live_transcribe('call-1', language: 'en-US')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.live_transcribe', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'en-US', last.body['params']['language']
  end

  def test_live_translate
    body = @client.calling.live_translate(
      'call-1', source_language: 'en', target_language: 'es',
    )
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.live_translate', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'en', last.body['params']['source_language']
    assert_equal 'es', last.body['params']['target_language']
  end

  # -------------------------------------------------------------------
  # Fax commands
  # -------------------------------------------------------------------

  def test_send_fax_stop
    body = @client.calling.send_fax_stop('call-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.send_fax.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
  end

  def test_receive_fax_stop
    body = @client.calling.receive_fax_stop('call-1')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.receive_fax.stop', last.body['command']
    assert_equal 'call-1', last.body['id']
  end

  # -------------------------------------------------------------------
  # SIP refer + custom user_event
  # -------------------------------------------------------------------

  def test_refer
    body = @client.calling.refer('call-1', to: 'sip:other@example.com')
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.refer', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'sip:other@example.com', last.body['params']['to']
  end

  def test_user_event
    body = @client.calling.user_event(
      'call-1', event_name: 'my-event', payload: { 'foo' => 'bar' },
    )
    assert_kind_of Hash, body
    assert body.key?('id')

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal 'calling.user_event', last.body['command']
    assert_equal 'call-1', last.body['id']
    assert_equal 'my-event', last.body['params']['event_name']
    assert_equal({ 'foo' => 'bar' }, last.body['params']['payload'])
  end
end
