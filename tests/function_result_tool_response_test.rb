# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require_relative '../lib/signalwire/swaig/function_result'

# The structured response form and the actions built on it: set_tool_response,
# hold(prompt, timeout, step:, timeout_step:), change_voice, and the
# global_data channel of rpc_ai_message / rpc_ai_global_data.
# Parity: signalwire-python tests/unit/core/test_function_result.py
# (TestHold*, TestChangeVoice) and core/function_result.py.
class FunctionResultToolResponseTest < Minitest::Test
  FR = SignalWire::Swaig::FunctionResult

  def test_set_tool_response_both_fields
    h = FR.new.set_tool_response(tool_result: 'status: on hold', tool_prompt: 'Tell them.').to_h

    assert_equal({ 'tool_result' => 'status: on hold', 'tool_prompt' => 'Tell them.' }, h['response'])
  end

  def test_set_tool_response_omits_an_absent_field
    r = FR.new.set_tool_response(tool_result: 'payment declined')

    assert_equal({ 'tool_result' => 'payment declined' }, r.response)
  end

  def test_set_tool_response_returns_self
    r = FR.new

    assert_same r, r.set_tool_response(tool_prompt: 'x')
  end

  def test_hold_bare_integer_form_is_unchanged
    assert_equal [{ 'hold' => 120 }], FR.new.hold(120).action
    assert_equal [{ 'hold' => 300 }], FR.new.hold.action
  end

  def test_hold_step_and_timeout_step_emit_object_form
    r = FR.new.hold(nil, 120, step: 'back_with_agent', timeout_step: 'take_a_message')

    assert_equal [{ 'hold' => { 'timeout' => 120, 'step' => 'back_with_agent',
                                'timeout_step' => 'take_a_message' } }], r.action
  end

  def test_hold_only_step
    assert_equal [{ 'hold' => { 'timeout' => 300, 'step' => 'back_with_agent' } }],
                 FR.new.hold(step: 'back_with_agent').action
  end

  def test_hold_only_timeout_step
    assert_equal [{ 'hold' => { 'timeout' => 60, 'timeout_step' => 'take_a_message' } }],
                 FR.new.hold(60, timeout_step: 'take_a_message').action
  end

  def test_hold_routing_clamps_timeout
    assert_equal [{ 'hold' => { 'timeout' => 900, 'step' => 's' } }],
                 FR.new.hold(nil, 5000, step: 's').action
  end

  def test_hold_prompt_becomes_the_response_and_turns_on_post_process
    h = FR.new.hold('Tell the caller you are placing them on hold.', 120).to_h

    assert_equal({ 'tool_result' => 'status: on hold',
                   'tool_prompt' => 'Tell the caller you are placing them on hold.' }, h['response'])
    assert h['post_process']
    assert_equal [{ 'hold' => 120 }], h['action']
  end

  def test_hold_boolean_is_neither_prompt_nor_timeout
    r = FR.new.hold(true)

    assert_equal [{ 'hold' => 300 }], r.action
    refute r.post_process
  end

  def test_change_voice_emits_string_form
    assert_equal [{ 'change_voice' => 'elevenlabs.rachel' }], FR.new.change_voice('elevenlabs.rachel').action
  end

  def test_change_voice_passes_model_suffix_through_verbatim
    r = FR.new.change_voice('gcloud.en-US-Neural2-A:chirp')

    assert_equal 'gcloud.en-US-Neural2-A:chirp', r.action[0]['change_voice']
  end

  def test_change_voice_serialized_wire_shape
    h = FR.new('Switching voices now').change_voice('amazon.Joanna').to_h

    assert_equal({ 'response' => 'Switching voices now', 'action' => [{ 'change_voice' => 'amazon.Joanna' }] }, h)
    assert_equal h, JSON.parse(JSON.generate(h))
  end

  def test_change_voice_chains_with_other_actions
    r = FR.new('ok')

    assert_same r, r.change_voice('elevenlabs.rachel').say('Hello again')
    assert_equal [{ 'change_voice' => 'elevenlabs.rachel' }, { 'say' => 'Hello again' }], r.action
  end

  def test_rpc_ai_message_global_data_only
    rpc = execute_rpc(FR.new.rpc_ai_message('call-1', global_data: { 'decline_message' => 'Sorry' }))

    assert_equal({ 'global_data' => { 'decline_message' => 'Sorry' } }, rpc['params'])
  end

  def test_rpc_ai_message_text_and_global_data
    rpc = execute_rpc(FR.new.rpc_ai_message('call-1', 'Hi', global_data: { 'k' => 'v' }))

    assert_equal({ 'role' => 'system', 'message_text' => 'Hi', 'global_data' => { 'k' => 'v' } }, rpc['params'])
  end

  def test_rpc_ai_message_needs_a_payload
    e = assert_raises(ArgumentError) { FR.new.rpc_ai_message('call-1') }
    assert_equal 'rpc_ai_message needs message_text, global_data, or both', e.message
  end

  def test_rpc_ai_global_data_is_the_global_data_only_message
    rpc = execute_rpc(FR.new.rpc_ai_global_data('call-9', { 'room' => '4B' }))

    assert_equal 'ai_message', rpc['method']
    assert_equal 'call-9', rpc['call_id']
    assert_equal({ 'global_data' => { 'room' => '4B' } }, rpc['params'])
  end

  private

  def execute_rpc(result)
    result.action.first['SWML']['sections']['main'][0]['execute_rpc']
  end
end
