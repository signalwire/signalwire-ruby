# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/web_search'

class WebSearchSkillDetailedTest < Minitest::Test
  def test_setup_requires_api_key_and_engine_id
    saved_key = ENV.delete('GOOGLE_SEARCH_API_KEY')
    saved_cx  = ENV.delete('GOOGLE_SEARCH_ENGINE_ID')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
      skill = factory.call({})
      refute skill.setup

      skill_partial = factory.call({ 'api_key' => 'key' })
      refute skill_partial.setup

      skill_full = factory.call({ 'api_key' => 'key', 'search_engine_id' => 'cx' })
      assert skill_full.setup
    ensure
      ENV['GOOGLE_SEARCH_API_KEY'] = saved_key if saved_key
      ENV['GOOGLE_SEARCH_ENGINE_ID'] = saved_cx if saved_cx
    end
  end

  def test_register_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'key', 'search_engine_id' => 'cx' })
    skill.setup
    tools = skill.register_tools
    assert_equal 1, tools.size
    assert_equal 'web_search', tools[0][:name]
  end

  def test_supports_multiple_instances
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx' })
    assert skill.supports_multiple_instances?
  end

  def test_instance_key_includes_tool_name
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx', 'tool_name' => 'custom_search' })
    skill.setup
    assert_includes skill.instance_key, 'custom_search'
  end

  def test_version
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({})
    assert_equal '2.0.0', skill.version
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx' })
    skill.setup
    data = skill.get_global_data
    assert_equal true, data['web_search_enabled']
  end
end
