# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class WebhookUrlTest < Minitest::Test
  def test_webhook_url_in_swml
    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'])
    agent.define_tool(name: 'test', description: 'Test') { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    default_url = ai['SWAIG']['defaults']['web_hook_url']
    assert_includes default_url, '/swaig'
    assert_includes default_url, 'u:p@'
  end

  def test_web_hook_url_override
    agent = SignalWire::AgentBase.new
    agent.set_web_hook_url('https://custom.example.com/hook')
    agent.define_tool(name: 'test', description: 'Test') { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 'https://custom.example.com/hook', ai['SWAIG']['defaults']['web_hook_url']
  end

  def test_post_prompt_url_in_swml
    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'])
    agent.set_post_prompt('Summarize')
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_includes ai['post_prompt_url'], '/post_prompt'
  end

  def test_post_prompt_url_override
    agent = SignalWire::AgentBase.new
    agent.set_post_prompt('Sum')
    agent.set_post_prompt_url('https://custom.example.com/pp')
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 'https://custom.example.com/pp', ai['post_prompt_url']
  end
end

class ProxyUrlTest < Minitest::Test
  def test_proxy_url_from_env
    ENV['SWML_PROXY_URL_BASE'] = 'https://proxy.example.com'
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 'test', description: 'Test') { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']
    assert_includes url, 'https://proxy.example.com'
  ensure
    ENV.delete('SWML_PROXY_URL_BASE')
  end

  def test_manual_set_proxy_url
    agent = SignalWire::AgentBase.new
    agent.manual_set_proxy_url('https://manual.example.com')
    agent.define_tool(name: 'test', description: 'Test') { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']
    assert_includes url, 'https://manual.example.com'
  end
end

class SwaigQueryParamsTest < Minitest::Test
  def test_add_swaig_query_params
    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'])
    agent.add_swaig_query_params({ 'tenant' => 'acme' })
    agent.define_tool(name: 'test', description: 'Test') { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']
    assert_includes url, 'tenant=acme'
  end

  def test_clear_swaig_query_params
    agent = SignalWire::AgentBase.new
    agent.add_swaig_query_params({ 'key' => 'val' })
    agent.clear_swaig_query_params
    agent.define_tool(name: 'test', description: 'Test') { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']
    refute_includes url, 'key=val'
  end
end

class DynamicConfigIsolationTest < Minitest::Test
  def test_dynamic_config_callback_applied
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('Original')
    agent.set_dynamic_config_callback do |_query, _body, _headers, ephemeral|
      ephemeral.set_prompt_text('Modified')
    end
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 'Modified', ai['prompt']['text']
  end

  def test_original_not_mutated
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('Original')
    agent.set_dynamic_config_callback do |_query, _body, _headers, ephemeral|
      ephemeral.set_prompt_text('Modified')
      ephemeral.add_hint('NewHint')
    end
    agent.render_swml
    assert_equal 'Original', agent.get_prompt
  end

  def test_dynamic_config_can_add_tools
    agent = SignalWire::AgentBase.new
    agent.set_dynamic_config_callback do |_q, _b, _h, ephemeral|
      ephemeral.define_tool(name: 'dynamic_tool', description: 'Added dynamically') { |_, _| }
    end
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    func_names = (ai.dig('SWAIG', 'functions') || []).map { |f| f['function'] }
    assert_includes func_names, 'dynamic_tool'
    assert_empty agent.define_tools
  end
end

class WebChainingTest < Minitest::Test
  def test_web_methods_return_self
    agent = SignalWire::AgentBase.new
    assert_same agent, agent.set_dynamic_config_callback { |*| }
    assert_same agent, agent.manual_set_proxy_url('x')
    assert_same agent, agent.set_web_hook_url('x')
    assert_same agent, agent.set_post_prompt_url('x')
    assert_same agent, agent.add_swaig_query_params({})
    assert_same agent, agent.clear_swaig_query_params
    assert_same agent, agent.enable_debug_routes
  end
end
