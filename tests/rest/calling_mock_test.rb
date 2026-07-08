# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_calling_mock.py.
#
# Every command in CallingNamespace is exercised here with the real Ruby
# RestClient wired to the in-process mock_signalwire server. Each test:
#
# 1. Calls the SDK method (no transport patching).
# 2. Asserts on the response body shape that the mock returns from the spec.
# 3. Asserts on @mock.last so we know the SDK sent the right
#    wire request — method, path, command field, and (where applicable)
#    the id and any keyword params.

require 'minitest/autorun'
require_relative 'mock_test'

# Shared setup/teardown + the calling-command journal assertion helpers.
# The suite is split into topic classes so no single class grows unbounded;
# they all mix in this module.
module CallingMockHelpers
  # Parallelize: each test's client uses a unique project + auth-scoped harness,
  # so the shared mock is concurrency-safe. Parallelism stress-proves isolation.
  def self.included(base)
    base.parallelize_me!
  end

  CALLS_PATH = '/api/calling/calls'

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  # Assert the common calling-command journal shape and return the entry.
  #
  # Every calling command POSTs to CALLS_PATH with a 'command' field and the
  # call id (or, for commands that embed the id in params like dial/update,
  # no top-level 'id' — pass id: nil to assert its absence). +params+ maps
  # param keys to expected values under last.body['params'].
  def assert_call_command(body, command:, id: nil, params: {})
    assert_kind_of Hash, body
    assert body.key?('id')

    last = @mock.last

    assert_command_envelope(last, command, id)
    params.each { |k, v| assert_equal v, last.body['params'][k], "params[#{k.inspect}]" }
    last
  end

  # Assert the POST/path/command/id envelope shared by every calling command.
  def assert_command_envelope(last, command, id)
    assert_equal 'POST', last.method
    assert_equal CALLS_PATH, last.path
    assert_equal command, last.body['command']
    if id
      assert_equal id, last.body['id']
    else
      refute last.body.key?('id')
    end
  end
end

class CallingMockTest < Minitest::Test
  include CallingMockHelpers

  # -------------------------------------------------------------------
  # Lifecycle commands
  # -------------------------------------------------------------------

  def test_dial_forwards_codecs_array
    body = @client.calling.dial(
      from: '+15550000000', to: '+15551234567', url: 'https://example.com/swml',
      codecs: %w[OPUS G729 VP8 PCMA]
    )

    assert_call_command(body, command: 'dial',
                              params: { 'from' => '+15550000000', 'to' => '+15551234567',
                                        'url' => 'https://example.com/swml',
                                        'codecs' => %w[OPUS G729 VP8 PCMA] })
  end

  def test_dial_forwards_codecs_string
    body = @client.calling.dial(
      from: '+15550000000', to: '+15551234567', url: 'https://example.com/swml',
      codecs: 'OPUS,G729,VP8,PCMA'
    )

    assert_call_command(body, command: 'dial',
                              params: { 'from' => '+15550000000', 'to' => '+15551234567',
                                        'url' => 'https://example.com/swml',
                                        'codecs' => 'OPUS,G729,VP8,PCMA' })
  end

  def test_update
    body = @client.calling.update(id: 'call-1', state: 'hold')

    last = assert_call_command(body, command: 'update',
                                     params: { 'id' => 'call-1', 'state' => 'hold' })

    refute_nil last.matched_route
  end

  def test_transfer
    body = @client.calling.transfer('call-123', dest: '+15551234567')

    assert_call_command(body, command: 'calling.transfer', id: 'call-123',
                              params: { 'dest' => '+15551234567' })
  end

  def test_disconnect
    body = @client.calling.disconnect('call-456', reason: 'busy')

    assert_call_command(body, command: 'calling.disconnect', id: 'call-456',
                              params: { 'reason' => 'busy' })
  end

  # -------------------------------------------------------------------
  # Play commands
  # -------------------------------------------------------------------

  def test_play_pause
    body = @client.calling.play_pause('call-1', control_id: 'ctrl-1')

    assert_call_command(body, command: 'calling.play.pause', id: 'call-1',
                              params: { 'control_id' => 'ctrl-1' })
  end

  def test_play_resume
    body = @client.calling.play_resume('call-1', control_id: 'ctrl-1')

    assert_call_command(body, command: 'calling.play.resume', id: 'call-1',
                              params: { 'control_id' => 'ctrl-1' })
  end

  def test_play_stop
    body = @client.calling.play_stop('call-1', control_id: 'ctrl-1')

    assert_call_command(body, command: 'calling.play.stop', id: 'call-1',
                              params: { 'control_id' => 'ctrl-1' })
  end

  def test_play_volume
    body = @client.calling.play_volume('call-1', control_id: 'ctrl-1', volume: 2.5)

    last = assert_call_command(body, command: 'calling.play.volume', id: 'call-1')

    assert_in_delta 2.5, last.body['params']['volume'], 0.0001
  end

  # -------------------------------------------------------------------
  # Record commands
  # -------------------------------------------------------------------

  def test_record
    body = @client.calling.record('call-1', record: { 'format' => 'mp3' })

    assert_call_command(body, command: 'calling.record', id: 'call-1',
                              params: { 'record' => { 'format' => 'mp3' } })
  end

  def test_record_pause
    body = @client.calling.record_pause('call-1', control_id: 'rec-1')

    assert_call_command(body, command: 'calling.record.pause', id: 'call-1',
                              params: { 'control_id' => 'rec-1' })
  end

  def test_record_resume
    body = @client.calling.record_resume('call-1', control_id: 'rec-1')

    assert_call_command(body, command: 'calling.record.resume', id: 'call-1',
                              params: { 'control_id' => 'rec-1' })
  end

  # -------------------------------------------------------------------
  # Collect commands
  # -------------------------------------------------------------------

  def test_collect
    body = @client.calling.collect('call-1', initial_timeout: 5, digits: { 'max' => 4 })

    assert_call_command(body, command: 'calling.collect', id: 'call-1',
                              params: { 'initial_timeout' => 5 })
  end

  def test_collect_stop
    body = @client.calling.collect_stop('call-1', control_id: 'col-1')

    assert_call_command(body, command: 'calling.collect.stop', id: 'call-1',
                              params: { 'control_id' => 'col-1' })
  end

  def test_collect_start_input_timers
    body = @client.calling.collect_start_input_timers('call-1', control_id: 'col-1')

    assert_call_command(body, command: 'calling.collect.start_input_timers', id: 'call-1',
                              params: { 'control_id' => 'col-1' })
  end
end

# Detect / tap / stream / denoise / transcribe, AI, live, fax, refer, user_event.
class CallingMockMediaTest < Minitest::Test
  include CallingMockHelpers

  # -------------------------------------------------------------------
  # Detect / tap / stream / denoise / transcribe
  # -------------------------------------------------------------------

  def test_detect
    body = @client.calling.detect('call-1', detect: { 'type' => 'machine', 'params' => {} })

    last = assert_call_command(body, command: 'calling.detect', id: 'call-1')

    assert_equal 'machine', last.body['params']['detect']['type']
  end

  def test_detect_stop
    body = @client.calling.detect_stop('call-1', control_id: 'det-1')

    assert_call_command(body, command: 'calling.detect.stop', id: 'call-1',
                              params: { 'control_id' => 'det-1' })
  end

  def test_tap
    body = @client.calling.tap(
      'call-1', tap: { 'type' => 'audio' }, device: { 'type' => 'rtp' }
    )

    assert_call_command(body, command: 'calling.tap', id: 'call-1',
                              params: { 'tap' => { 'type' => 'audio' } })
  end

  def test_tap_stop
    body = @client.calling.tap_stop('call-1', control_id: 'tap-1')

    assert_call_command(body, command: 'calling.tap.stop', id: 'call-1',
                              params: { 'control_id' => 'tap-1' })
  end

  def test_stream
    body = @client.calling.stream('call-1', url: 'wss://example.com/audio')

    assert_call_command(body, command: 'calling.stream', id: 'call-1',
                              params: { 'url' => 'wss://example.com/audio' })
  end

  def test_stream_stop
    body = @client.calling.stream_stop('call-1', control_id: 'stream-1')

    assert_call_command(body, command: 'calling.stream.stop', id: 'call-1',
                              params: { 'control_id' => 'stream-1' })
  end

  def test_denoise
    body = @client.calling.denoise('call-1')

    assert_call_command(body, command: 'calling.denoise', id: 'call-1')
  end

  def test_denoise_stop
    body = @client.calling.denoise_stop('call-1', control_id: 'dn-1')

    assert_call_command(body, command: 'calling.denoise.stop', id: 'call-1',
                              params: { 'control_id' => 'dn-1' })
  end

  def test_transcribe
    body = @client.calling.transcribe(
      'call-1', language: 'en-US', transcribe: { 'engine' => 'google' }
    )

    assert_call_command(body, command: 'calling.transcribe', id: 'call-1',
                              params: { 'language' => 'en-US' })
  end

  def test_transcribe_stop
    body = @client.calling.transcribe_stop('call-1', control_id: 'tr-1')

    assert_call_command(body, command: 'calling.transcribe.stop', id: 'call-1',
                              params: { 'control_id' => 'tr-1' })
  end

  # -------------------------------------------------------------------
  # AI commands
  # -------------------------------------------------------------------

  def test_ai_hold
    body = @client.calling.ai_hold('call-1')

    assert_call_command(body, command: 'calling.ai_hold', id: 'call-1')
  end

  def test_ai_unhold
    body = @client.calling.ai_unhold('call-1')

    assert_call_command(body, command: 'calling.ai_unhold', id: 'call-1')
  end

  def test_ai_stop
    body = @client.calling.ai_stop('call-1', control_id: 'ai-1')

    assert_call_command(body, command: 'calling.ai.stop', id: 'call-1',
                              params: { 'control_id' => 'ai-1' })
  end

  # -------------------------------------------------------------------
  # Live transcribe / translate
  # -------------------------------------------------------------------

  def test_live_transcribe
    body = @client.calling.live_transcribe('call-1', action: 'start')

    assert_call_command(body, command: 'calling.live_transcribe', id: 'call-1',
                              params: { 'action' => 'start' })
  end

  def test_live_translate
    body = @client.calling.live_translate(
      'call-1', action: 'start', status_url: 'https://example.com/status'
    )

    assert_call_command(body, command: 'calling.live_translate', id: 'call-1',
                              params: { 'action' => 'start', 'status_url' => 'https://example.com/status' })
  end

  # -------------------------------------------------------------------
  # Fax commands
  # -------------------------------------------------------------------

  def test_send_fax_stop
    body = @client.calling.send_fax_stop('call-1', control_id: 'fax-1')

    assert_call_command(body, command: 'calling.send_fax.stop', id: 'call-1',
                              params: { 'control_id' => 'fax-1' })
  end

  def test_receive_fax_stop
    body = @client.calling.receive_fax_stop('call-1', control_id: 'fax-1')

    assert_call_command(body, command: 'calling.receive_fax.stop', id: 'call-1',
                              params: { 'control_id' => 'fax-1' })
  end

  # -------------------------------------------------------------------
  # SIP refer + custom user_event
  # -------------------------------------------------------------------

  def test_refer
    body = @client.calling.refer('call-1', device: 'sip:other@example.com')

    assert_call_command(body, command: 'calling.refer', id: 'call-1',
                              params: { 'device' => 'sip:other@example.com' })
  end

  def test_user_event
    body = @client.calling.user_event('call-1', event: { 'foo' => 'bar' })

    assert_call_command(body, command: 'calling.user_event', id: 'call-1',
                              params: { 'event' => { 'foo' => 'bar' } })
  end
end
