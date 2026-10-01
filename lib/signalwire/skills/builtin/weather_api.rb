# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'
require_relative '../../datamap/data_map'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # Current weather from WeatherAPI.com as a DataMap tool: the request runs ON
      # SignalWire's servers, so there is no webhook back to this agent. Requires a
      # `WEATHER_API_KEY` (or an `api_key` param).
      class WeatherApiSkill < SkillBase
        # The name this skill is added under (`agent.add_skill('weather_api')`).
        #
        # @return [String]
        def name = 'weather_api'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
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

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
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
              'function' => tool_name,
              'description' => 'Get current weather information for any location',
              'parameters' => tool_parameters,
              'data_map' => tool_data_map
            }
          ]
        end

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          get_tools.map { |tool| { datamap: tool } }
        end

        private

        attr_reader :api_key, :tool_name, :temp_unit

        # @api private — the tool's JSON Schema: one required `location` string, which
        # the model fills from what the caller said.
        #
        # @return [Hash]
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

        # @api private — the DataMap: the weather webhook, `error` as the failure key,
        # and the fallback message as the output used when the request fails.
        #
        # @return [Hash]
        def tool_data_map
          {
            'webhooks' => [weather_webhook],
            'error_keys' => ['error'],
            'output' => Swaig::FunctionResult.new(fallback_message).to_h
          }
        end

        # @api private — the WeatherAPI request the platform issues. The location is
        # the SWML expression `${lc:enc:args.location}` — lower-cased and URL-encoded
        # server-side — so the model's raw argument is never spliced into the URL
        # unescaped.
        #
        # @return [Hash]
        def weather_webhook
          {
            'url' => "#{base_url}/v1/current.json?key=#{api_key}&q=${lc:enc:args.location}&aqi=no",
            'method' => 'GET',
            'output' => Swaig::FunctionResult.new(response_template).to_h
          }
        end

        # @api private — which WeatherAPI response fields and unit name to use for the
        # configured `temperature_unit`: the `_c` fields for celsius, otherwise the
        # `_f` fields.
        #
        # @return [Hash{Symbol => String}]
        def temperature_fields
          if temp_unit == 'celsius'
            { temp: 'temp_c', feels: 'feelslike_c', unit: 'Celsius' }
          else
            { temp: 'temp_f', feels: 'feelslike_f', unit: 'Fahrenheit' }
          end
        end

        # @api private — the instruction the model receives, with the WeatherAPI
        # response interpolated by SWML expressions. It asks for temperatures as
        # natural-language numbers without symbols or abbreviations, because the text
        # is spoken by TTS.
        #
        # @return [String]
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

        # @api private — what the model is told when the weather request fails, phrased
        # so it can offer the caller a retry or a corrected location.
        #
        # @return [String]
        def fallback_message
          'Sorry, I cannot get weather information right now. ' \
            'Please try again later or check if the location name is correct.'
        end

        public

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
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
