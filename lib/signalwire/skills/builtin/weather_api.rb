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

        # Extracts the configuration (tool_name / api_key / temperature_unit)
        # off ``params`` at construction time so the ivars exist immediately.
        # {#setup} re-reads them (and returns the validation bool).
        def initialize(agent = nil, params = nil)
          super
          @api_key   = get_param('api_key', env_var: 'WEATHER_API_KEY')
          @tool_name = get_param('tool_name', default: 'get_weather')
          @temp_unit = get_param('temperature_unit', default: 'fahrenheit')
        end

        def setup
          @api_key   = get_param('api_key', env_var: 'WEATHER_API_KEY')
          @tool_name = get_param('tool_name', default: 'get_weather')
          @temp_unit = get_param('temperature_unit', default: 'fahrenheit')
          return false unless @api_key && !@api_key.empty?

          true
        end

        # Returns the raw SWAIG tool DEFINITION hashes (the DataMap tool the
        # skill provides). {#register_tools} builds on top of this.
        def get_tools
          [
            {
              'function' => @tool_name,
              'description' => 'Get current weather information for any location',
              'parameters' => tool_parameters,
              'data_map' => tool_data_map
            }
          ]
        end

        def register_tools
          get_tools.map { |tool| { datamap: tool } }
        end

        private

        def tool_parameters
          {
            'type' => 'object',
            'properties' => {
              'location' => { 'type' => 'string',
                              'description' => 'The city, state, country, or location to get weather for' }
            },
            'required' => ['location']
          }
        end

        def tool_data_map
          {
            'webhooks' => [weather_webhook],
            'error_keys' => ['error'],
            'output' => Swaig::FunctionResult.new(fallback_message).to_h
          }
        end

        def weather_webhook
          {
            'url' => "#{base_url}/v1/current.json?key=#{@api_key}&q=${lc:enc:args.location}&aqi=no",
            'method' => 'GET',
            'output' => Swaig::FunctionResult.new(response_template).to_h
          }
        end

        def temperature_fields
          if @temp_unit == 'celsius'
            { temp: 'temp_c', feels: 'feelslike_c', unit: 'Celsius' }
          else
            { temp: 'temp_f', feels: 'feelslike_f', unit: 'Fahrenheit' }
          end
        end

        def response_template
          temp_field, feels_field, unit_name = temperature_fields.values_at(:temp, :feels, :unit)
          'Tell the user the current weather conditions. ' \
            "Express all temperatures in #{unit_name} using natural language numbers " \
            'without abbreviations or symbols for clear text-to-speech pronunciation. ' \
            'Current conditions: ${current.condition.text}. ' \
            "Temperature: ${current.#{temp_field}} degrees #{unit_name}. " \
            'Wind: ${current.wind_dir} at ${current.wind_mph} miles per hour. ' \
            'Cloud coverage: ${current.cloud} percent. ' \
            "Feels like: ${current.#{feels_field}} degrees #{unit_name}."
        end

        # Default to the WeatherAPI.com host; WEATHER_API_BASE_URL
        # overrides for tests and the audit fixture. The `/v1/current.json`
        # path is preserved so the audit can match on `current.json`.
        def base_url
          resolved_base_url('WEATHER_API_BASE_URL', 'https://api.weatherapi.com')
        end

        def fallback_message
          'Sorry, I cannot get weather information right now. ' \
            'Please try again later or check if the location name is correct.'
        end

        public

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
