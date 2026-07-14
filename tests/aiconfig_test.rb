# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class AIConfigHintsTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_add_hint
    @agent.add_hint('SignalWire')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_includes ai['hints'], 'SignalWire'
  end

  def test_add_hints
    @agent.add_hints(%w[one two three])
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal %w[one two three], ai['hints']
  end

  def test_add_pattern_hint
    @agent.add_pattern_hint('SW.*', hint: 'SignalWire', language: 'en-US')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    pattern_hint = ai['hints'].find { |h| h.is_a?(Hash) }

    assert_equal 'SW.*', pattern_hint['pattern']
    assert_equal 'SignalWire', pattern_hint['hint']
  end

  def test_add_empty_hint_ignored
    @agent.add_hint('')
    @agent.add_hint('valid')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal ['valid'], ai['hints']
  end
end

class AIConfigLanguagesTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_add_language
    @agent.add_language({ 'name' => 'English', 'code' => 'en-US', 'voice' => 'rachel' })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 1, ai['languages'].length
    assert_equal 'English', ai['languages'][0]['name']
  end

  def test_set_languages
    langs = [
      { 'name' => 'English', 'code' => 'en-US', 'voice' => 'rachel' },
      { 'name' => 'French', 'code' => 'fr-FR', 'voice' => 'amelie' }
    ]
    @agent.set_languages(langs)
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 2, ai['languages'].length
  end

  # #34 regression (RED on the pre-fix code, which raised ArgumentError
  # "wrong number of arguments (given 0)"). A braceless string-keyed hash —
  # `add_language('name' => …, 'code' => …, 'voice' => …)` — is routed by Ruby
  # toward keywords; it must be accepted as the hash config form.
  def test_add_language_braceless_string_keyed_hash
    @agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'rachel')
    langs = @agent.instance_variable_get(:@languages)

    assert_equal 1, langs.length
    assert_equal 'English', langs[0]['name']
    assert_equal 'en-US', langs[0]['code']
    assert_equal 'rachel', langs[0]['voice']
  end

  # The braceless symbol-keyed shape must also work, with keys stringified to
  # match SWML's string-keyed language config.
  def test_add_language_braceless_symbol_keyed_hash
    @agent.add_language(name: 'French', code: 'fr-FR', voice: 'amelie')
    langs = @agent.instance_variable_get(:@languages)

    assert_equal 'French', langs[0]['name']
    assert_equal 'fr-FR', langs[0]['code']
  end

  # The positional form remains supported (no regression).
  def test_add_language_positional_form
    @agent.add_language('Spanish', 'es-ES', 'es-ES-Neural2-A')
    langs = @agent.instance_variable_get(:@languages)

    assert_equal 'Spanish', langs[0]['name']
    assert_equal 'es-ES-Neural2-A', langs[0]['voice']
  end
end

# Ports Python 029ca6f: per-language params via add_language(params:),
# set_language_params, get_language_params. The params key is emitted
# only when non-empty so existing language entries stay byte-identical.
class AIConfigPerLanguageParamsTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def languages
    @agent.instance_variable_get(:@languages)
  end

  def test_add_language_with_params_attaches_params
    @agent.add_language('English', 'en-US', 'josh', engine: 'elevenlabs',
                                                    params: { 'stability' => 0.5, 'similarity_boost' => 0.75 })

    assert_equal({ 'stability' => 0.5, 'similarity_boost' => 0.75 },
                 languages[0]['params'])
  end

  def test_add_language_without_params_omits_key
    @agent.add_language('French', 'fr-FR', 'fr-FR-Neural2-A')

    refute languages[0].key?('params')
  end

  def test_add_language_with_empty_params_omits_key
    @agent.add_language('French', 'fr-FR', 'v', params: {})

    refute languages[0].key?('params')
  end

  def test_get_language_params_returns_set_hash
    @agent.add_language('English', 'en-US', 'v', params: { 'a' => 1 })

    assert_equal({ 'a' => 1 }, @agent.get_language_params('en-US'))
  end

  def test_get_language_params_returns_nil_when_unset
    @agent.add_language('English', 'en-US', 'v')

    assert_nil @agent.get_language_params('en-US')
  end

  def test_get_language_params_returns_nil_for_unknown_code
    assert_nil @agent.get_language_params('zh-CN')
  end

  def test_set_language_params_replaces_existing
    @agent.add_language('English', 'en-US', 'v', params: { 'a' => 1 })
    @agent.set_language_params('en-US', { 'b' => 2 })

    assert_equal({ 'b' => 2 }, @agent.get_language_params('en-US'))
  end

  def test_set_language_params_adds_when_unset
    @agent.add_language('English', 'en-US', 'v')
    @agent.set_language_params('en-US', { 'c' => 3 })

    assert_equal({ 'c' => 3 }, @agent.get_language_params('en-US'))
  end

  def test_set_language_params_empty_hash_removes_key
    @agent.add_language('English', 'en-US', 'v', params: { 'a' => 1 })
    @agent.set_language_params('en-US', {})

    assert_nil @agent.get_language_params('en-US')
    refute languages[0].key?('params')
  end

  def test_set_language_params_unknown_code_is_noop
    @agent.add_language('English', 'en-US', 'v')
    @agent.set_language_params('zh-CN', { 'a' => 1 })
    # The known language remains untouched.
    assert_nil languages[0]['params']
  end

  def test_set_language_params_returns_self_for_chaining
    @agent.add_language('English', 'en-US', 'v')

    assert_same @agent, @agent.set_language_params('en-US', { 'a' => 1 })
  end

  def test_params_emitted_into_swml_when_present
    @agent.add_language('English', 'en-US', 'josh', engine: 'elevenlabs',
                                                    params: { 'stability' => 0.5 })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal({ 'stability' => 0.5 }, ai['languages'][0]['params'])
  end
end

class AIConfigPronunciationsTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_add_pronunciation
    @agent.add_pronunciation('SW', 'SignalWire')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 'SW', ai['pronounce'][0]['replace']
    assert_equal 'SignalWire', ai['pronounce'][0]['with']
  end

  def test_set_pronunciations
    rules = [{ 'replace' => 'AI', 'with' => 'Artificial Intelligence' }]
    @agent.set_pronunciations(rules)
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 1, ai['pronounce'].length
  end
end

class AIConfigParamsTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_set_param
    @agent.set_param('temperature', 0.7)
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_in_delta(0.7, ai['params']['temperature'])
  end

  def test_set_params
    @agent.set_params({ 'temperature' => 0.7, 'top_p' => 0.9 })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_in_delta(0.7, ai['params']['temperature'])
    assert_in_delta(0.9, ai['params']['top_p'])
  end
end

class AIConfigGlobalDataTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_set_global_data
    @agent.set_global_data({ 'key' => 'value' })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 'value', ai['global_data']['key']
  end

  def test_update_global_data
    @agent.set_global_data({ 'a' => 1 })
    @agent.update_global_data({ 'b' => 2 })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 1, ai['global_data']['a']
    assert_equal 2, ai['global_data']['b']
  end
end

class AIConfigNativeFunctionsTest < Minitest::Test
  def test_set_native_functions
    agent = SignalWire::AgentBase.new
    agent.set_native_functions(['check_for_input'])
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_includes ai['SWAIG']['native_functions'], 'check_for_input'
  end
end

class AIConfigFillersTest < Minitest::Test
  def test_set_internal_fillers
    agent = SignalWire::AgentBase.new
    agent.set_internal_fillers({
                                 'next_step' => { 'en-US' => ['Moving on...'] }
                               })
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal ['Moving on...'], ai['SWAIG']['internal_fillers']['next_step']['en-US']
  end

  def test_add_internal_filler
    agent = SignalWire::AgentBase.new
    agent.add_internal_filler('check_time', 'en-US', ['Checking time...'])
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal ['Checking time...'], ai['SWAIG']['internal_fillers']['check_time']['en-US']
  end
end

class AIConfigDebugEventsTest < Minitest::Test
  def test_enable_debug_events
    agent = SignalWire::AgentBase.new
    agent.enable_debug_events(2)
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert ai['params'].key?('debug_webhook_url')
    assert_equal 2, ai['params']['debug_webhook_level']
  end
end

class AIConfigFunctionIncludesTest < Minitest::Test
  def test_add_function_include
    agent = SignalWire::AgentBase.new
    agent.add_function_include('https://example.com/funcs', %w[fn1 fn2],
                               meta_data: { 'key' => 'val' })
    inc = rendered_ai(agent)['SWAIG']['includes']

    assert_equal 1, inc.length
    assert_equal({ 'url' => 'https://example.com/funcs', 'functions' => %w[fn1 fn2],
                   'meta_data' => { 'key' => 'val' } },
                 inc[0])
  end

  def rendered_ai(agent)
    agent.render_swml['sections']['main'].find { |v| v.key?('ai') }['ai']
  end

  def test_set_function_includes
    agent = SignalWire::AgentBase.new
    includes = [{ 'url' => 'https://a.com', 'functions' => ['f1'] }]
    agent.set_function_includes(includes)
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 1, ai['SWAIG']['includes'].length
  end
end

class AIConfigLLMParamsTest < Minitest::Test
  def test_set_prompt_llm_params
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('Hello')
    agent.set_prompt_llm_params(temperature: 0.3, top_p: 0.9)
    ai = agent.render_swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    prompt = ai['prompt']

    assert_in_delta(0.3, prompt['temperature'])
    assert_in_delta(0.9, prompt['top_p'])
    assert_equal 'Hello', prompt['text']
  end

  def test_set_post_prompt_llm_params
    agent = SignalWire::AgentBase.new
    agent.set_post_prompt('Summarize')
    agent.set_post_prompt_llm_params(model: 'gpt-4o-mini', temperature: 0.5)
    ai = agent.render_swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    post = ai['post_prompt']

    assert_in_delta(0.5, post['temperature'])
    assert_equal 'gpt-4o-mini', post['model']
    assert_equal 'Summarize', post['text']
  end
end

class AIConfigChainingTest < Minitest::Test
  def test_hint_and_language_setters_return_self
    agent = SignalWire::AgentBase.new

    assert_same agent, agent.add_hint('x')
    assert_same agent, agent.add_hints(['x'])
    assert_same agent, agent.add_pattern_hint('p')
    assert_same agent, agent.add_language({ 'name' => 'E', 'code' => 'en' })
    assert_same agent, agent.set_languages([])
    assert_same agent, agent.add_pronunciation('a', 'b')
    assert_same agent, agent.set_pronunciations([])
  end

  def test_param_and_data_setters_return_self
    agent = SignalWire::AgentBase.new

    assert_same agent, agent.set_param('k', 'v')
    assert_same agent, agent.set_params({})
    assert_same agent, agent.set_global_data({})
    assert_same agent, agent.update_global_data({})
    assert_same agent, agent.set_native_functions([])
    assert_same agent, agent.set_internal_fillers({})
    assert_same agent, agent.add_internal_filler('f', 'en', ['x'])
  end

  def test_function_and_llm_setters_return_self
    agent = SignalWire::AgentBase.new

    assert_same agent, agent.enable_debug_events
    assert_same agent, agent.add_function_include('url', ['f'])
    assert_same agent, agent.set_function_includes([])
    assert_same agent, agent.set_prompt_llm_params(temperature: 0.5)
    assert_same agent, agent.set_post_prompt_llm_params(temperature: 0.5)
  end
end

# ===========================================================================
# Behavioral contract #2: set_prompt_llm_params / set_post_prompt_llm_params
# MERGE (not replace). Python does self._prompt_llm_params.update(params).
# Two calls with distinct keys must leave BOTH keys present in the rendered
# SWML — a replace stub would drop the first key.
# ===========================================================================
class AIConfigLlmParamsMergeTest < Minitest::Test
  def prompt_obj(agent)
    swml = agent.render_swml
    swml['sections']['main'].find { |v| v.key?('ai') }['ai']['prompt']
  end

  def post_prompt_obj(agent)
    swml = agent.render_swml
    swml['sections']['main'].find { |v| v.key?('ai') }['ai']['post_prompt']
  end

  def test_set_prompt_llm_params_merges_across_calls
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('hi')
    agent.set_prompt_llm_params(temperature: 0.5)
    agent.set_prompt_llm_params(top_p: 0.9)

    prompt = prompt_obj(agent)

    assert_in_delta 0.5, prompt['temperature'], 1e-9, 'first key must survive the second call (merge, not replace)'
    assert_in_delta 0.9, prompt['top_p'], 1e-9
  end

  def test_set_post_prompt_llm_params_merges_across_calls
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('hi')
    agent.set_post_prompt('summarize')
    agent.set_post_prompt_llm_params(temperature: 0.3)
    agent.set_post_prompt_llm_params(top_p: 0.8)

    pp = post_prompt_obj(agent)

    assert_in_delta 0.3, pp['temperature'], 1e-9, 'first post-prompt key must survive the second call'
    assert_in_delta 0.8, pp['top_p'], 1e-9
  end

  def test_prompt_llm_params_last_write_wins_on_same_key
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('hi')
    agent.set_prompt_llm_params(temperature: 0.5)
    agent.set_prompt_llm_params(temperature: 0.2)

    assert_in_delta 0.2, prompt_obj(agent)['temperature'], 1e-9
  end
end
