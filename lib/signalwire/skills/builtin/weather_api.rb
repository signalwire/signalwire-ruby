# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'
require_relative '../../datamap/data_map'

module SignalWire
  module Skills
    module Builtin
      class WeatherApiSkill < SkillBase
        def name = 'weather_api'
        def description = 'Get current weather information from WeatherAPI.com'

        def setup
          @api_key   = get_param('api_key', env_var: 'WEATHER_API_KEY')
          @tool_name = get_param('tool_name', default: 'get_weather')
          @temp_unit = get_param('temperature_unit', default: 'fahrenheit')
          return false unless @api_key && !@api_key.empty?

          true
        end

        def register_tools
          if @temp_unit == 'celsius'
            temp_field      = 'temp_c'
            feels_field     = 'feelslike_c'
            unit_name       = 'Celsius'
          else
            temp_field      = 'temp_f'
            feels_field     = 'feelslike_f'
            unit_name       = 'Fahrenheit'
          end

          response_template =
            'Tell the user the current weather conditions. ' \
            "Express all temperatures in #{unit_name} using natural language numbers " \
            'without abbreviations or symbols for clear text-to-speech pronunciation. ' \
            'Current conditions: ${current.condition.text}. ' \
            "Temperature: ${current.#{temp_field}} degrees #{unit_name}. " \
            'Wind: ${current.wind_dir} at ${current.wind_mph} miles per hour. ' \
            'Cloud coverage: ${current.cloud} percent. ' \
            "Feels like: ${current.#{feels_field}} degrees #{unit_name}."

          # Default to the WeatherAPI.com host; WEATHER_API_BASE_URL
          # overrides for tests and the audit fixture. The `/v1/current.json`
          # path is preserved so the audit can match on `current.json`.
          base = ENV.fetch('WEATHER_API_BASE_URL', nil)
          base = 'https://api.weatherapi.com' if base.nil? || base.empty?
          base = base.sub(%r{/$}, '')

          tool = {
            'function' => @tool_name,
            'description' => 'Get current weather information for any location',
            'parameters' => {
              'type' => 'object',
              'properties' => {
                'location' => { 'type' => 'string',
                                'description' => 'The city, state, country, or location to get weather for' }
              },
              'required' => ['location']
            },
            'data_map' => {
              'webhooks' => [
                {
                  'url' => "#{base}/v1/current.json?key=#{@api_key}&q=${lc:enc:args.location}&aqi=no",
                  'method' => 'GET',
                  'output' => Swaig::FunctionResult.new(response_template).to_h
                }
              ],
              'error_keys' => ['error'],
              'output' => Swaig::FunctionResult.new(
                'Sorry, I cannot get weather information right now. Please try again later or check if the location name is correct.'
              ).to_h
            }
          }

          [{ datamap: tool }]
        end

        def get_parameter_schema
          {
            'api_key' => { 'type' => 'string', 'required' => true, 'hidden' => true,
                           'env_var' => 'WEATHER_API_KEY' },
            'tool_name' => { 'type' => 'string', 'default' => 'get_weather' },
            'temperature_unit' => { 'type' => 'string', 'default' => 'fahrenheit', 'enum' => %w[fahrenheit celsius] }
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('weather_api') do |params|
  SignalWire::Skills::Builtin::WeatherApiSkill.new(params)
end
