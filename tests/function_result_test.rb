# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require_relative '../lib/signalwire/swaig/function_result'

class FunctionResultTest < Minitest::Test
  FR = SignalWire::Swaig::FunctionResult

  # ------------------------------------------------------------------
  # Construction
  # ------------------------------------------------------------------

  def test_default_construction
    r = FR.new

    assert_equal '', r.response
    assert_equal [], r.action
    refute r.post_process
  end

  def test_construction_with_response
    r = FR.new('Hello')

    assert_equal 'Hello', r.response
  end

  def test_construction_with_nil_response
    r = FR.new(nil)

    assert_equal '', r.response
  end

  def test_construction_with_post_process
    r = FR.new('Hi', post_process: true)

    assert r.post_process
  end

  # ------------------------------------------------------------------
  # Serialization (to_h)
  # ------------------------------------------------------------------

  def test_to_h_response_only
    h = FR.new('Hello').to_h

    assert_equal({ 'response' => 'Hello' }, h)
    refute h.key?('action')
    refute h.key?('post_process')
  end

  def test_to_h_with_action
    h = FR.new('Hello').add_action('hangup', true).to_h

    assert_equal 'Hello', h['response']
    assert_equal [{ 'hangup' => true }], h['action']
    refute h.key?('post_process')
  end

  def test_to_h_post_process_only_with_actions
    # post_process=true but no actions => not included
    h = FR.new('Hello', post_process: true).to_h

    refute h.key?('post_process')

    # post_process=true with actions => included
    h = FR.new('Hello', post_process: true).hangup.to_h

    assert h['post_process']
  end

  def test_to_h_empty_result_gets_default_response
    r = FR.new('')
    h = r.to_h

    assert_equal 'Action completed.', h['response']
  end

  def test_to_json
    r = FR.new('Test')
    parsed = JSON.parse(r.to_json)

    assert_equal 'Test', parsed['response']
  end

  # ------------------------------------------------------------------
  # Method chaining
  # ------------------------------------------------------------------

  def test_method_chaining_returns_self
    r = FR.new('Start')

    assert_same r, r.set_response('Changed')
    assert_same r, r.set_post_process(true)
    assert_same r, r.add_action('test', 'value')
    assert_same r, r.add_actions([{ 'x' => 1 }])
    assert_same r, r.hangup
    assert_same r, r.hold
    assert_same r, r.stop
    assert_same r, r.say('hi')
    assert_same r, r.update_global_data('k' => 'v')
    assert_same r, r.connect('+15551234567')
  end

  def test_fluent_chain
    h = FR.new('Processing')
          .update_global_data('status' => 'active')
          .say('Working on it')
          .hangup
          .to_h

    assert_equal 'Processing', h['response']
    assert_equal 3, h['action'].length
  end

  # ------------------------------------------------------------------
  # Call Control
  # ------------------------------------------------------------------

  def test_connect_basic
    r = FR.new('Transferring')
    r.connect('+15551234567')
    action = r.action.first
    swml = action['SWML']

    assert_equal '+15551234567', swml['sections']['main'][0]['connect']['to']
    assert_equal '1.0.0', swml['version']
    assert_equal 'true', action['transfer']
  end

  def test_connect_with_from_addr
    r = FR.new.connect('+15551234567', from_addr: '+15559876543')
    connect = r.action.first['SWML']['sections']['main'][0]['connect']

    assert_equal '+15559876543', connect['from']
  end

  def test_connect_non_final
    r = FR.new.connect('+15551234567', final: false)

    assert_equal 'false', r.action.first['transfer']
  end

  def test_swml_transfer
    r = FR.new.swml_transfer('https://example.com/swml', 'Goodbye!', final: true)
    action = r.action.first
    main = action['SWML']['sections']['main']

    assert_equal({ 'ai_response' => 'Goodbye!' }, main[0]['set'])
    assert_equal({ 'dest' => 'https://example.com/swml' }, main[1]['transfer'])
    assert_equal 'true', action['transfer']
  end

  def test_hangup
    h = FR.new('Bye').hangup.to_h

    assert_equal [{ 'hangup' => true }], h['action']
  end

  def test_hold_clamps_timeout
    r = FR.new
    r.hold(1500)

    assert_equal [{ 'hold' => 900 }], r.action

    r2 = FR.new
    r2.hold(-10)

    assert_equal [{ 'hold' => 0 }], r2.action
  end

  def test_hold_default
    r = FR.new.hold

    assert_equal [{ 'hold' => 300 }], r.action
  end

  def test_wait_for_user_defaults
    r = FR.new.wait_for_user

    assert_equal [{ 'wait_for_user' => true }], r.action
  end

  def test_wait_for_user_answer_first
    r = FR.new.wait_for_user(answer_first: true)

    assert_equal [{ 'wait_for_user' => 'answer_first' }], r.action
  end

  def test_wait_for_user_timeout
    r = FR.new.wait_for_user(timeout: 30)

    assert_equal [{ 'wait_for_user' => 30 }], r.action
  end

  def test_wait_for_user_enabled_false
    r = FR.new.wait_for_user(enabled: false)

    assert_equal [{ 'wait_for_user' => false }], r.action
  end

  def test_stop
    h = FR.new('Stopping').stop.to_h

    assert_equal [{ 'stop' => true }], h['action']
  end

  # ------------------------------------------------------------------
  # State & Data Management
  # ------------------------------------------------------------------

  def test_update_global_data
    r = FR.new.update_global_data('key1' => 'value1', 'key2' => 'value2')
    expected = { 'set_global_data' => { 'key1' => 'value1', 'key2' => 'value2' } }

    assert_equal expected, r.action.first
  end

  def test_remove_global_data
    r = FR.new.remove_global_data(%w[key1 key2])

    assert_equal({ 'unset_global_data' => %w[key1 key2] }, r.action.first)
  end

  def test_set_metadata
    r = FR.new.set_metadata('k' => 'v')

    assert_equal({ 'set_meta_data' => { 'k' => 'v' } }, r.action.first)
  end

  def test_remove_metadata
    r = FR.new.remove_metadata(%w[a b])

    assert_equal({ 'unset_meta_data' => %w[a b] }, r.action.first)
  end

  def test_swml_user_event
    r = FR.new.swml_user_event('event_name' => 'test', 'data' => 'payload')
    swml = r.action.first['SWML']
    event = swml['sections']['main'][0]['user_event']['event']

    assert_equal 'test', event['event_name']
    assert_equal '1.0.0', swml['version']
  end

  def test_swml_change_step
    r = FR.new.swml_change_step('betting')

    assert_equal({ 'change_step' => 'betting' }, r.action.first)
  end

  def test_swml_change_context
    r = FR.new.swml_change_context('support')

    assert_equal({ 'change_context' => 'support' }, r.action.first)
  end

  def test_switch_context_simple
    r = FR.new.switch_context(system_prompt: 'You are a helpful assistant')

    assert_equal({ 'context_switch' => 'You are a helpful assistant' }, r.action.first)
  end

  def test_switch_context_full
    r = FR.new.switch_context(
      system_prompt: 'New prompt',
      user_prompt: 'User says',
      consolidate: true,
      full_reset: true,
      isolated: true
    )
    ctx = r.action.first['context_switch']

    assert_equal 'New prompt', ctx['system_prompt']
    assert_equal 'User says', ctx['user_prompt']
    assert ctx['consolidate']
    assert ctx['full_reset']
    assert ctx['isolated']
  end

  def test_replace_in_history_with_text
    r = FR.new.replace_in_history('summary text')

    assert_equal({ 'replace_in_history' => 'summary text' }, r.action.first)
  end

  def test_replace_in_history_default
    r = FR.new.replace_in_history

    assert_equal({ 'replace_in_history' => true }, r.action.first)
  end

  # ------------------------------------------------------------------
  # Media Control
  # ------------------------------------------------------------------

  def test_say
    r = FR.new.say('Hello there')

    assert_equal({ 'say' => 'Hello there' }, r.action.first)
  end

  def test_play_background_file
    r = FR.new.play_background_file('music.mp3')

    assert_equal({ 'playback_bg' => 'music.mp3' }, r.action.first)
  end

  def test_play_background_file_with_wait
    r = FR.new.play_background_file('music.mp3', wait: true)

    assert_equal({ 'playback_bg' => { 'file' => 'music.mp3', 'wait' => true } }, r.action.first)
  end

  def test_stop_background_file
    r = FR.new.stop_background_file

    assert_equal({ 'stop_playback_bg' => true }, r.action.first)
  end

  def test_record_call_default
    r = FR.new.record_call
    swml = r.action.first['SWML']
    rec = swml['sections']['main'][0]['record_call']

    assert_equal false, rec['stereo']
    assert_equal 'wav', rec['format']
    assert_equal 'both', rec['direction']
    refute rec.key?('control_id')
  end

  def test_record_call_with_control_id
    r = FR.new.record_call(control_id: 'rec-1', stereo: true, format: 'mp3')
    swml = r.action.first['SWML']
    rec = swml['sections']['main'][0]['record_call']

    assert_equal 'rec-1', rec['control_id']
    assert_equal true, rec['stereo']
    assert_equal 'mp3', rec['format']
  end

  def test_record_call_bad_format
    assert_raises(ArgumentError) { FR.new.record_call(format: 'ogg') }
  end

  def test_stop_record_call
    r = FR.new.stop_record_call
    swml = r.action.first['SWML']
    stop = swml['sections']['main'][0]['stop_record_call']

    assert_equal({}, stop)
  end

  def test_stop_record_call_with_id
    r = FR.new.stop_record_call(control_id: 'rec-1')
    swml = r.action.first['SWML']
    stop = swml['sections']['main'][0]['stop_record_call']

    assert_equal 'rec-1', stop['control_id']
  end

  # ------------------------------------------------------------------
  # Speech & AI
  # ------------------------------------------------------------------

  def test_add_dynamic_hints
    hints = ['Cabby', { 'pattern' => 'cab bee', 'replace' => 'Cabby' }]
    r = FR.new.add_dynamic_hints(hints)

    assert_equal({ 'add_dynamic_hints' => hints }, r.action.first)
  end

  def test_clear_dynamic_hints
    r = FR.new.clear_dynamic_hints

    assert_equal({ 'clear_dynamic_hints' => {} }, r.action.first)
  end

  def test_set_end_of_speech_timeout
    r = FR.new.set_end_of_speech_timeout(500)

    assert_equal({ 'end_of_speech_timeout' => 500 }, r.action.first)
  end

  def test_set_speech_event_timeout
    r = FR.new.set_speech_event_timeout(3000)

    assert_equal({ 'speech_event_timeout' => 3000 }, r.action.first)
  end

  def test_toggle_functions
    toggles = [
      { 'function' => 'func1', 'active' => true },
      { 'function' => 'func2', 'active' => false }
    ]
    r = FR.new.toggle_functions(toggles)

    assert_equal({ 'toggle_functions' => toggles }, r.action.first)
  end

  def test_enable_functions_on_timeout
    r = FR.new.enable_functions_on_timeout

    assert_equal({ 'functions_on_speaker_timeout' => true }, r.action.first)

    r2 = FR.new.enable_functions_on_timeout(false)

    assert_equal({ 'functions_on_speaker_timeout' => false }, r2.action.first)
  end

  def test_enable_extensive_data
    r = FR.new.enable_extensive_data

    assert_equal({ 'extensive_data' => true }, r.action.first)
  end

  def test_update_settings
    r = FR.new.update_settings('temperature' => 0.5, 'top_p' => 0.9)

    assert_equal({ 'settings' => { 'temperature' => 0.5, 'top_p' => 0.9 } }, r.action.first)
  end

  # ------------------------------------------------------------------
  # Advanced
  # ------------------------------------------------------------------

  def test_execute_swml_hash
    swml = { 'version' => '1.0.0', 'sections' => { 'main' => [{ 'answer' => {} }] } }
    r = FR.new.execute_swml(swml)

    assert_equal swml, r.action.first['SWML']
  end

  def test_execute_swml_json_string
    swml_json = '{"version":"1.0.0","sections":{"main":[]}}'
    r = FR.new.execute_swml(swml_json)

    assert_equal '1.0.0', r.action.first['SWML']['version']
  end

  def test_execute_swml_with_transfer
    swml = { 'version' => '1.0.0', 'sections' => {} }
    r = FR.new.execute_swml(swml, transfer: true)

    assert_equal 'true', r.action.first['SWML']['transfer']
  end

  def test_execute_swml_bad_type
    assert_raises(TypeError) { FR.new.execute_swml(42) }
  end

  # ------------------------------------------------------------------
  # join_conference — full parity with Python reference
  # (tests/unit/core/test_function_result.py::TestJoinConference)
  # Python raises ValueError; Ruby idiom is ArgumentError. Error message
  # text mirrors Python's exact f-string rendering, including the
  # "one of ['a', 'b']" list form.
  # ------------------------------------------------------------------

  # Parity: test_join_conference_simple_name_all_defaults
  def test_join_conference_simple
    r = FR.new.join_conference('my_conf')
    swml = r.action.first['SWML']
    # Simple form: bare conference name string, not a hash
    assert_equal 'my_conf', swml['sections']['main'][0]['join_conference']
  end

  # Parity: test_join_conference_complex_params — every non-default param
  # is emitted under its snake_case wire key in the object form.
  def test_join_conference_complex_params
    r = FR.new.join_conference(
      'team-meeting',
      muted: true,
      beep: 'onEnter',
      start_on_enter: false,
      end_on_exit: true,
      wait_url: 'https://example.com/hold-music',
      max_participants: 50,
      record: 'record-from-start',
      region: 'us-east',
      trim: 'do-not-trim',
      coach: 'call-id-123',
      status_callback_event: 'start end',
      status_callback: 'https://example.com/callback',
      status_callback_method: 'GET',
      recording_status_callback: 'https://example.com/rec-callback',
      recording_status_callback_method: 'GET',
      recording_status_callback_event: 'in-progress',
      result: { 'key' => 'value' }
    )
    join = r.action.first['SWML']['sections']['main'][0]['join_conference']

    assert_instance_of Hash, join
    assert_equal 'team-meeting', join['name']
    assert_equal true, join['muted']
    assert_equal 'onEnter', join['beep']
    assert_equal false, join['start_on_enter']
    assert_equal true, join['end_on_exit']
    assert_equal 'https://example.com/hold-music', join['wait_url']
    assert_equal 50, join['max_participants']
    assert_equal 'record-from-start', join['record']
    assert_equal 'us-east', join['region']
    assert_equal 'do-not-trim', join['trim']
    assert_equal 'call-id-123', join['coach']
    assert_equal 'start end', join['status_callback_event']
    assert_equal 'https://example.com/callback', join['status_callback']
    assert_equal 'GET', join['status_callback_method']
    assert_equal 'https://example.com/rec-callback', join['recording_status_callback']
    assert_equal 'GET', join['recording_status_callback_method']
    assert_equal 'in-progress', join['recording_status_callback_event']
    assert_equal({ 'key' => 'value' }, join['result'])
    # No holdAudio key — Python uses wait_url.
    refute join.key?('holdAudio')
  end

  def test_join_conference_with_options
    r = FR.new.join_conference('my_conf', muted: true, record: 'record-from-start')
    swml = r.action.first['SWML']
    join = swml['sections']['main'][0]['join_conference']

    assert_equal 'my_conf', join['name']
    assert_equal true, join['muted']
    assert_equal 'record-from-start', join['record']
    # Defaults are omitted from the object form.
    refute join.key?('beep')
    refute join.key?('max_participants')
    refute join.key?('status_callback_method')
  end

  # Parity: test_join_conference_invalid_beep
  def test_join_conference_invalid_beep
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', beep: 'invalid') }
    assert_equal "beep must be one of ['true', 'false', 'onEnter', 'onExit']", e.message
  end

  # Parity: test_join_conference_max_participants_too_high
  def test_join_conference_max_participants_too_high
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', max_participants: 300) }
    assert_equal 'max_participants must be a positive integer <= 250', e.message
  end

  # Parity: test_join_conference_max_participants_zero
  def test_join_conference_max_participants_zero
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', max_participants: 0) }
    assert_equal 'max_participants must be a positive integer <= 250', e.message
  end

  # Parity: test_join_conference_max_participants_negative
  def test_join_conference_max_participants_negative
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', max_participants: -5) }
    assert_equal 'max_participants must be a positive integer <= 250', e.message
  end

  # Parity: test_join_conference_invalid_record
  def test_join_conference_invalid_record
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', record: 'always') }
    assert_equal "record must be one of ['do-not-record', 'record-from-start']", e.message
  end

  # Parity: test_join_conference_invalid_trim
  def test_join_conference_invalid_trim
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', trim: 'bad-value') }
    assert_equal "trim must be one of ['trim-silence', 'do-not-trim']", e.message
  end

  # Parity: test_join_conference_empty_name
  def test_join_conference_bad_name
    e = assert_raises(ArgumentError) { FR.new.join_conference('', muted: true) }
    assert_equal 'name cannot be empty', e.message
  end

  # Parity: test_join_conference_whitespace_name
  def test_join_conference_whitespace_name
    e = assert_raises(ArgumentError) { FR.new.join_conference('   ', muted: true) }
    assert_equal 'name cannot be empty', e.message
  end

  # Parity: test_join_conference_invalid_status_callback_method
  # (currently MISSING in Ruby — RED until the GET/POST check is added)
  def test_join_conference_invalid_status_callback_method
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', status_callback_method: 'PUT') }
    assert_equal "status_callback_method must be one of ['GET', 'POST']", e.message
  end

  # Parity: test_join_conference_invalid_recording_status_callback_method
  # (currently MISSING in Ruby — RED until the GET/POST check is added)
  def test_join_conference_invalid_recording_status_callback_method
    e = assert_raises(ArgumentError) { FR.new.join_conference('conf', recording_status_callback_method: 'DELETE') }
    assert_equal "recording_status_callback_method must be one of ['GET', 'POST']", e.message
  end

  # Parity: test_join_conference_chaining
  def test_join_conference_chaining
    r = FR.new

    assert_same r, r.join_conference('conf')
  end

  def test_join_room
    r = FR.new.join_room('test-room')
    swml = r.action.first['SWML']

    assert_equal({ 'name' => 'test-room' }, swml['sections']['main'][0]['join_room'])
  end

  def test_sip_refer
    r = FR.new.sip_refer('sip:user@example.com')
    swml = r.action.first['SWML']

    assert_equal({ 'to_uri' => 'sip:user@example.com' }, swml['sections']['main'][0]['sip_refer'])
  end

  def test_tap_basic
    r = FR.new.tap('rtp://10.0.0.1:9000')
    swml = r.action.first['SWML']
    tap_p = swml['sections']['main'][0]['tap']

    assert_equal 'rtp://10.0.0.1:9000', tap_p['uri']
    refute tap_p.key?('direction') # default not included
    refute tap_p.key?('codec')
  end

  def test_tap_with_options
    r = FR.new.tap('ws://example.com', control_id: 'tap-1', direction: 'speak', codec: 'PCMA')
    swml = r.action.first['SWML']
    tap_p = swml['sections']['main'][0]['tap']

    assert_equal 'tap-1', tap_p['control_id']
    assert_equal 'speak', tap_p['direction']
    assert_equal 'PCMA', tap_p['codec']
  end

  def test_tap_bad_direction
    assert_raises(ArgumentError) { FR.new.tap('rtp://x', direction: 'invalid') }
  end

  def test_stop_tap
    r = FR.new.stop_tap
    swml = r.action.first['SWML']

    assert_equal({}, swml['sections']['main'][0]['stop_tap'])
  end

  def test_stop_tap_with_id
    r = FR.new.stop_tap(control_id: 'tap-1')
    swml = r.action.first['SWML']

    assert_equal({ 'control_id' => 'tap-1' }, swml['sections']['main'][0]['stop_tap'])
  end

  def test_send_sms
    r = FR.new.send_sms(
      to_number: '+15551234567',
      from_number: '+15559876543',
      body: 'Hello!',
      media: ['https://example.com/image.jpg'],
      tags: ['vip']
    )
    swml = r.action.first['SWML']
    sms = swml['sections']['main'][0]['send_sms']

    assert_equal '+15551234567', sms['to_number']
    assert_equal '+15559876543', sms['from_number']
    assert_equal 'Hello!', sms['body']
    assert_equal ['https://example.com/image.jpg'], sms['media']
    assert_equal ['vip'], sms['tags']
  end

  def test_send_sms_requires_body_or_media
    assert_raises(ArgumentError) do
      FR.new.send_sms(to_number: '+1', from_number: '+2')
    end
  end

  def test_send_sms_media_only
    r = FR.new.send_sms(
      to_number: '+15551234567',
      from_number: '+15559876543',
      media: ['https://example.com/image.jpg']
    )
    swml = r.action.first['SWML']
    sms = swml['sections']['main'][0]['send_sms']

    assert_equal ['https://example.com/image.jpg'], sms['media']
    refute sms.key?('body')
  end

  def test_pay
    r = FR.new.pay(
      payment_connector_url: 'https://pay.example.com',
      charge_amount: '9.99'
    )
    swml = r.action.first['SWML']
    main = swml['sections']['main']

    assert main[0].key?('set')
    pay_p = main[1]['pay']

    assert_equal 'https://pay.example.com', pay_p['payment_connector_url']
    assert_equal '9.99', pay_p['charge_amount']
    assert_equal 'dtmf', pay_p['input']
  end

  # ------------------------------------------------------------------
  # RPC
  # ------------------------------------------------------------------

  def test_execute_rpc
    r = FR.new.execute_rpc('custom_method', params: { 'key' => 'value' })
    swml = r.action.first['SWML']
    rpc = swml['sections']['main'][0]['execute_rpc']

    assert_equal 'custom_method', rpc['method']
    assert_equal({ 'key' => 'value' }, rpc['params'])
  end

  def test_execute_rpc_no_params
    r = FR.new.execute_rpc('simple_method')
    swml = r.action.first['SWML']
    rpc = swml['sections']['main'][0]['execute_rpc']

    assert_equal 'simple_method', rpc['method']
    refute rpc.key?('params')
  end

  def test_rpc_dial
    r = FR.new.rpc_dial(
      to_number: '+15551234567',
      from_number: '+15559876543',
      dest_swml: 'https://example.com/agent'
    )
    swml = r.action.first['SWML']
    rpc = swml['sections']['main'][0]['execute_rpc']

    assert_equal 'dial', rpc['method']
    assert_equal '+15551234567', rpc['params']['devices']['params']['to_number']
    assert_equal 'https://example.com/agent', rpc['params']['dest_swml']
  end

  def test_rpc_ai_message
    r = FR.new.rpc_ai_message('call-123', 'Hello from system')
    swml = r.action.first['SWML']
    rpc = swml['sections']['main'][0]['execute_rpc']

    assert_equal 'ai_message', rpc['method']
    assert_equal 'call-123', rpc['call_id']
    assert_equal 'system', rpc['params']['role']
    assert_equal 'Hello from system', rpc['params']['message_text']
  end

  def test_rpc_ai_unhold
    r = FR.new.rpc_ai_unhold('call-456')
    swml = r.action.first['SWML']
    rpc = swml['sections']['main'][0]['execute_rpc']

    assert_equal 'ai_unhold', rpc['method']
    assert_equal 'call-456', rpc['call_id']
  end

  def test_simulate_user_input
    r = FR.new.simulate_user_input('I need help')

    assert_equal({ 'user_input' => 'I need help' }, r.action.first)
  end

  # ------------------------------------------------------------------
  # Payment helpers (class methods)
  # ------------------------------------------------------------------

  def test_create_payment_prompt
    actions = [FR.create_payment_action('Say', 'Enter your card')]
    prompt = FR.create_payment_prompt('payment-card-number', actions,
                                      card_type: 'visa', error_type: 'invalid-card')

    assert_equal 'payment-card-number', prompt['for']
    assert_equal 1, prompt['actions'].length
    assert_equal 'visa', prompt['card_type']
    assert_equal 'invalid-card', prompt['error_type']
  end

  def test_create_payment_prompt_minimal
    prompt = FR.create_payment_prompt('payment-card-number', [])

    refute prompt.key?('card_type')
    refute prompt.key?('error_type')
  end

  def test_create_payment_action
    action = FR.create_payment_action('Say', 'Please enter your card number')

    assert_equal 'Say', action['type']
    assert_equal 'Please enter your card number', action['phrase']
  end

  def test_create_payment_parameter
    param = FR.create_payment_parameter('merchant_id', 'abc123')

    assert_equal 'merchant_id', param['name']
    assert_equal 'abc123', param['value']
  end

  # ------------------------------------------------------------------
  # Edge cases
  # ------------------------------------------------------------------

  def test_add_actions_batch
    r = FR.new
    r.add_actions([
                    { 'hangup' => true },
                    { 'say' => 'goodbye' }
                  ])

    assert_equal 2, r.action.length
  end

  def test_set_response_overrides
    r = FR.new('original')
    r.set_response('updated')

    assert_equal 'updated', r.response
  end

  def test_empty_string_response_gives_default
    r = FR.new('')
    h = r.to_h

    assert_equal 'Action completed.', h['response']
  end

  def test_nil_param_in_global_data
    r = FR.new.update_global_data('key' => nil)

    assert_equal({ 'set_global_data' => { 'key' => nil } }, r.action.first)
  end

  def test_complex_chain
    h = FR.new('Processing your request', post_process: true)
          .update_global_data('status' => 'active')
          .toggle_functions([{ 'function' => 'lookup', 'active' => false }])
          .say('One moment please')
          .record_call(control_id: 'rec-main')
          .to_h

    assert_equal 'Processing your request', h['response']
    assert_equal 4, h['action'].length
    assert h['post_process']
  end
end

# --- Idiomatic Ruby accessor aliases (RUBY_ERGONOMICS_MIGRATION.md) ---
class FunctionResultIdiomaticAccessorsTest < Minitest::Test
  def test_writers_mirror_setters
    fr = SignalWire::Swaig::FunctionResult.new
    fr.response = 'hi'

    assert_equal 'hi', fr.to_h['response']
    assert_equal 'x', (fr.response = 'x') # = returns RHS

    # metadata= mirrors set_metadata, which appends a set_meta_data action.
    fr2 = SignalWire::Swaig::FunctionResult.new
    fr2.metadata = { 'k' => 'v' }
    actions = Array(fr2.to_h['action'])

    assert(actions.any? { |a| a.is_a?(Hash) && a['set_meta_data'] == { 'k' => 'v' } },
           "expected a set_meta_data action, got #{actions.inspect}")
  end
end
