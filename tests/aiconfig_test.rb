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
    @agent.add_hints(['one', 'two', 'three'])
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal ['one', 'two', 'three'], ai['hints']
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
    assert_equal 0.7, ai['params']['temperature']
  end

  def test_set_params
    @agent.set_params({ 'temperature' => 0.7, 'top_p' => 0.9 })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 0.7, ai['params']['temperature']
    assert_equal 0.9, ai['params']['top_p']
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
    agent.add_function_include('https://example.com/funcs', ['fn1', 'fn2'],
                                meta_data: { 'key' => 'val' })
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    inc = ai['SWAIG']['includes']
    assert_equal 1, inc.length
    assert_equal 'https://example.com/funcs', inc[0]['url']
    assert_equal ['fn1', 'fn2'], inc[0]['functions']
    assert_equal({ 'key' => 'val' }, inc[0]['meta_data'])
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
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 0.3, ai['prompt']['temperature']
    assert_equal 0.9, ai['prompt']['top_p']
    assert_equal 'Hello', ai['prompt']['text']
  end

  def test_set_post_prompt_llm_params
    agent = SignalWire::AgentBase.new
    agent.set_post_prompt('Summarize')
    agent.set_post_prompt_llm_params(model: 'gpt-4o-mini', temperature: 0.5)
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 0.5, ai['post_prompt']['temperature']
    assert_equal 'gpt-4o-mini', ai['post_prompt']['model']
    assert_equal 'Summarize', ai['post_prompt']['text']
  end
end

class AIConfigChainingTest < Minitest::Test
  def test_all_ai_config_methods_return_self
    agent = SignalWire::AgentBase.new
    assert_same agent, agent.add_hint('x')
    assert_same agent, agent.add_hints(['x'])
    assert_same agent, agent.add_pattern_hint('p')
    assert_same agent, agent.add_language({ 'name' => 'E', 'code' => 'en' })
    assert_same agent, agent.set_languages([])
    assert_same agent, agent.add_pronunciation('a', 'b')
    assert_same agent, agent.set_pronunciations([])
    assert_same agent, agent.set_param('k', 'v')
    assert_same agent, agent.set_params({})
    assert_same agent, agent.set_global_data({})
    assert_same agent, agent.update_global_data({})
    assert_same agent, agent.set_native_functions([])
    assert_same agent, agent.set_internal_fillers({})
    assert_same agent, agent.add_internal_filler('f', 'en', ['x'])
    assert_same agent, agent.enable_debug_events
    assert_same agent, agent.add_function_include('url', ['f'])
    assert_same agent, agent.set_function_includes([])
    assert_same agent, agent.set_prompt_llm_params(temperature: 0.5)
    assert_same agent, agent.set_post_prompt_llm_params(temperature: 0.5)
  end
end
