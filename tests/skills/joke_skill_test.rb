# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/datamap/data_map'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/joke'

class JokeSkillDetailedTest < Minitest::Test
  def test_setup_requires_api_key
    saved = ENV.delete('API_NINJAS_KEY')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
      skill = factory.call({})

      refute skill.setup

      skill_with_key = factory.call({ 'api_key' => 'test_key' })

      assert skill_with_key.setup
    ensure
      ENV['API_NINJAS_KEY'] = saved if saved
    end
  end

  def test_setup_with_env_var
    ENV['API_NINJAS_KEY'] = 'env_test_key'
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
      skill = factory.call({})

      assert skill.setup
    ensure
      ENV.delete('API_NINJAS_KEY')
    end
  end

  def test_register_tools_returns_datamap
    factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
    skill = factory.call({ 'api_key' => 'test_key' })
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert tools[0].key?(:datamap), 'Joke skill should return a datamap tool'
    assert_equal 'get_joke', tools[0][:datamap]['function']
  end

  def test_custom_tool_name
    factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
    skill = factory.call({ 'api_key' => 'key', 'tool_name' => 'tell_joke' })
    skill.setup
    tools = skill.register_tools

    assert_equal 'tell_joke', tools[0][:datamap]['function']
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
    skill = factory.call({ 'api_key' => 'key' })
    skill.setup
    data = skill.get_global_data

    assert_equal true, data['joke_skill_enabled']
  end

  def test_prompt_sections
    factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
    skill = factory.call({ 'api_key' => 'key' })
    skill.setup
    sections = skill.get_prompt_sections

    assert_equal 1, sections.size
    assert_equal 'Joke Telling', sections[0]['title']
  end

  def test_parameter_schema
    factory = SignalWire::Skills::SkillRegistry.get_factory('joke')
    skill = factory.call({})
    schema = skill.get_parameter_schema

    assert schema.key?('api_key')
    assert schema.key?('tool_name')
  end
end
