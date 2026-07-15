# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/signalwire/skills/builtin/weather_api'

class WeatherApiSkillDetailedTest < Minitest::Test
  include TestHelper::Helpers

  # Each input path of the old test_setup_requires_api_key is now its own
  # method so a failure pinpoints which path broke.
  def test_setup_fails_without_api_key
    without_env_vars('WEATHER_API_KEY') do
      skill = build_skill('weather_api')

      refute skill.setup, 'weather_api must fail setup without an API key'
    end
  end

  def test_setup_succeeds_with_api_key
    without_env_vars('WEATHER_API_KEY') do
      skill = build_skill('weather_api', 'api_key' => 'test_key')

      assert skill.setup, 'weather_api must set up once an API key is provided'
    end
  end

  # The exact parameters schema the weather_api datamap advertises.
  EXPECTED_PARAMETERS = {
    'type' => 'object',
    'properties' => {
      'location' => { 'type' => 'string',
                      'description' => 'The city, state, country, or location to get weather for' }
    },
    'required' => ['location']
  }.freeze

  def test_register_tools_returns_datamap
    skill = build_skill('weather_api', 'api_key' => 'test_key')
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    # Exact shape of the returned datamap tool (was: presence-only key check).
    assert_weather_datamap(tools[0][:datamap])
  end

  # Assert the full shape of the weather datamap tool.
  def assert_weather_datamap(datamap)
    assert_kind_of Hash, datamap
    assert_equal 'get_weather', datamap['function']
    assert_equal 'Get current weather information for any location', datamap['description']
    assert_equal EXPECTED_PARAMETERS, datamap['parameters']
    assert_equal ['error'], datamap['data_map']['error_keys']
    assert_weather_webhook(datamap['data_map']['webhooks'][0])
  end

  # Assert the shape of the weather datamap's single webhook.
  def assert_weather_webhook(webhook)
    assert_equal 'GET', webhook['method']
    assert_includes webhook['url'], 'api.weatherapi.com/v1/current.json'
    assert_includes webhook['url'], 'key=test_key'
    assert_includes webhook['output']['response'], 'Fahrenheit'
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
