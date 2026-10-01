# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/core/post_prompt'

# Post-prompt normalization across the voice and chat engines.
# Parity: signalwire-python tests/unit/core/test_post_prompt_normalize.py.
class CorePostPromptParseTest < Minitest::Test
  PP = SignalWire::Core::PostPrompt
  FENCED = "```json\n{\"summary\": \"s\", \"already_answered\": [\"pricing\"]}\n```"

  def test_flat_keys_from_the_voice_engine
    assert_equal({ 'summary' => 's', 'user_goal' => 'g' },
                 PP.parse_post_prompt_data({ 'summary' => 's', 'user_goal' => 'g' }))
  end

  def test_fenced_raw_from_the_chat_engine
    assert_equal({ 'summary' => 's', 'already_answered' => ['pricing'] },
                 PP.parse_post_prompt_data({ 'raw' => FENCED }))
  end

  def test_object_wrapped_in_a_list_under_parsed
    assert_equal({ 'summary' => 's3' },
                 PP.parse_post_prompt_data({ 'parsed' => [{ 'summary' => 's3' }], 'raw' => '...' }))
  end

  def test_parsed_wrapper_wins_over_the_generic_sweep
    refute_includes PP.parse_post_prompt_data({ 'parsed' => [{ 'summary' => 's' }] }), 'parsed'
  end

  def test_parsed_as_a_bare_hash
    assert_equal({ 'summary' => 's' }, PP.parse_post_prompt_data({ 'parsed' => { 'summary' => 's' } }))
  end

  def test_prose_instead_of_json_is_kept
    assert_equal({ 'summary' => 'They asked about pricing.' },
                 PP.parse_post_prompt_data({ 'raw' => 'They asked about pricing.' }))
  end

  def test_json_that_is_not_an_object
    assert_equal({ 'summary' => 'just a string' }, PP.parse_post_prompt_data({ 'raw' => '"just a string"' }))
  end

  def test_junk_degrades_rather_than_raising
    [nil, {}, 'text', 42, [], { 'raw' => '' }, { 'raw' => '   ' }, { 'raw' => nil }].each do |junk|
      assert_equal({}, PP.parse_post_prompt_data(junk), junk.inspect)
    end
  end

  def test_strip_json_fence_unwraps
    { "```json\n{\"a\":1}\n```" => '{"a":1}', "```\nplain\n```" => 'plain',
      'no fence at all' => 'no fence at all', '' => '' }.each do |raw, expected|
      assert_equal expected, PP.strip_json_fence(raw)
    end
  end
end

# dialogue_turns + normalize_post_prompt.
class CorePostPromptNormalizeTest < Minitest::Test
  PP = SignalWire::Core::PostPrompt
  FENCED = CorePostPromptParseTest::FENCED

  LOG = [
    { 'role' => 'user', 'content' => 'hi' },
    { 'role' => 'assistant', 'content' => 'hello' },
    { 'role' => 'system', 'content' => 'the prompt' },
    { 'role' => 'system-log', 'content' => 'step trace' },
    { 'role' => 'tool', 'content' => 'tool output' },
    { 'role' => 'assistant', 'content' => '', 'tool_calls' => [{ 'id' => 1 }] },
    { 'role' => 'assistant-manual', 'content' => 'let me look that up' },
    { 'role' => 'assistant', 'content' => '   ' },
    'not even a dict'
  ].freeze

  def test_keeps_only_real_dialogue
    assert_equal [{ 'role' => 'user', 'content' => 'hi' }, { 'role' => 'assistant', 'content' => 'hello' }],
                 PP.dialogue_turns(LOG)
  end

  def test_drops_the_chat_summary_echo
    log = [*LOG, { 'role' => 'assistant', 'content' => FENCED }]

    refute_includes PP.dialogue_turns(log, drop_echo: FENCED), { 'role' => 'assistant', 'content' => FENCED }
  end

  def test_keeps_the_echo_when_not_asked_to_drop_it
    assert_equal 3, PP.dialogue_turns([*LOG, { 'role' => 'assistant', 'content' => FENCED }]).length
  end

  def test_junk_logs_yield_nothing
    [nil, [], 'nonsense', 42].each { |junk| assert_equal [], PP.dialogue_turns(junk) }
  end

  def test_voice_body
    result = PP.normalize_post_prompt({ 'conversation_type' => 'voice', 'call_id' => 'c-1',
                                        'post_prompt_data' => { 'parsed' => [{ 'summary' => 'v' }] },
                                        'raw_call_log' => [{ 'role' => 'user', 'content' => 'hi' }] })

    assert_equal 'voice', result.medium
    assert_nil result.conversation_id
    assert_equal({ 'summary' => 'v' }, result.summary)
    assert_equal 'c-1', result.call_id
    assert_equal 1, result.dialogue.length
  end

  def test_chat_body
    result = PP.normalize_post_prompt({ 'conversation_type' => 'chat', 'conversation_id' => 'conv-9',
                                        'post_prompt_data' => { 'raw' => FENCED },
                                        'raw_messages' => [{ 'role' => 'user', 'content' => 'hi' },
                                                           { 'role' => 'assistant', 'content' => FENCED }] })

    assert_equal 'chat', result.medium
    assert_equal 'conv-9', result.conversation_id
    assert_equal ['pricing'], result.summary['already_answered']
    assert_equal [{ 'role' => 'user', 'content' => 'hi' }], result.dialogue
  end

  def test_call_log_key_is_also_accepted
    assert_equal 1,
                 PP.normalize_post_prompt({ 'call_log' => [{ 'role' => 'user', 'content' => 'hi' }] }).dialogue.length
  end

  def test_junk_body_yields_empty_fields
    [nil, 'text', 42, []].each do |junk|
      result = PP.normalize_post_prompt(junk)

      assert_equal '', result.medium
      assert_equal({}, result.summary)
      assert_equal [], result.dialogue
    end
  end

  def test_raw_is_preserved
    body = { 'conversation_type' => 'voice', 'extra' => 'kept' }

    assert_same body, PP.normalize_post_prompt(body).raw
  end

  def test_result_is_frozen
    assert_predicate PP.normalize_post_prompt({}), :frozen?
  end
end
