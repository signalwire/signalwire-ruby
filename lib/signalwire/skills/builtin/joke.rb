# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'
require_relative '../../datamap/data_map'

module SignalWire
  module Skills
    module Builtin
      class JokeSkill < SkillBase
        FALLBACK_MESSAGE = 'Sorry, there is a problem with the joke service right now. ' \
                           'Please try again later.'

        def name = 'joke'
        def description = 'Tell jokes using the API Ninjas joke API'

        def setup
          @api_key   = get_param('api_key', env_var: 'API_NINJAS_KEY')
          @tool_name = get_param('tool_name', default: 'get_joke')
          return false unless @api_key && !@api_key.empty?

          true
        end

        def register_tools
          dm = DataMap.new(@tool_name)
                      .description('Get a random joke from API Ninjas')
                      .parameter('type', 'string', 'Type of joke to get', required: true, enum: %w[jokes dadjokes])
                      .webhook('GET', 'https://api.api-ninjas.com/v1/${args.type}',
                               headers: { 'X-Api-Key' => @api_key })
                      .output(Swaig::FunctionResult.new("Here's a joke: ${array[0].joke}"))
                      .error_keys(%w[error])
                      .fallback_output(Swaig::FunctionResult.new(FALLBACK_MESSAGE))

          [{ datamap: dm.to_swaig_function }]
        end

        # Returns [] — this skill ships no example hints.
        def get_hints = []

        def get_global_data
          { 'joke_skill_enabled' => true }
        end

        def get_prompt_sections
          [
            {
              'title' => 'Joke Telling',
              'body' => 'You can tell jokes to entertain users.',
              'bullets' => joke_telling_bullets
            }
          ]
        end

        def joke_telling_bullets
          [
            "Use #{@tool_name || 'get_joke'} to tell jokes when users ask for humor",
            'You can tell regular jokes or dad jokes',
            'Be enthusiastic and fun when sharing jokes'
          ]
        end
        private :joke_telling_bullets

        def get_parameter_schema
          {
            'api_key' => { 'type' => 'string', 'required' => true, 'hidden' => true, 'env_var' => 'API_NINJAS_KEY' },
            'tool_name' => { 'type' => 'string', 'default' => 'get_joke' }
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('joke') do |params|
  SignalWire::Skills::Builtin::JokeSkill.new(params)
end
