# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/datamap/data_map'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/weather_api'

class WeatherApiSkillDetailedTest < Minitest::Test
  def test_setup_requires_api_key
    saved = ENV.delete('WEATHER_API_KEY')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('weather_api')
      skill = factory.call({})

      refute skill.setup

      skill_with_key = factory.call({ 'api_key' => 'test_key' })

      assert skill_with_key.setup
    ensure
      ENV['WEATHER_API_KEY'] = saved if saved
    end
  end

  def test_register_tools_returns_datamap
    factory = SignalWire::Skills::SkillRegistry.get_factory('weather_api')
    skill = factory.call({ 'api_key' => 'test_key' })
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert tools[0].key?(:datamap)
    assert_equal 'get_weather', tools[0][:datamap]['function']
  end

  def test_custom_tool_name
    factory = SignalWire::Skills::SkillRegistry.get_factory('weather_api')
    skill = factory.call({ 'api_key' => 'key', 'tool_name' => 'check_weather' })
    skill.setup
    tools = skill.register_tools

    assert_equal 'check_weather', tools[0][:datamap]['function']
  end

  def test_celsius_mode
    factory = SignalWire::Skills::SkillRegistry.get_factory('weather_api')
    skill = factory.call({ 'api_key' => 'key', 'temperature_unit' => 'celsius' })
    skill.setup
    tools = skill.register_tools
    dm = tools[0][:datamap]
    output_response = dm['data_map']['webhooks'][0]['output']['response']

    assert_includes output_response, 'Celsius'
  end

  def test_fahrenheit_mode_default
    factory = SignalWire::Skills::SkillRegistry.get_factory('weather_api')
    skill = factory.call({ 'api_key' => 'key' })
    skill.setup
    tools = skill.register_tools
    dm = tools[0][:datamap]
    output_response = dm['data_map']['webhooks'][0]['output']['response']

    assert_includes output_response, 'Fahrenheit'
  end

  def test_parameter_schema
    factory = SignalWire::Skills::SkillRegistry.get_factory('weather_api')
    skill = factory.call({})
    schema = skill.get_parameter_schema

    assert schema.key?('api_key')
    assert schema.key?('temperature_unit')
  end
end
