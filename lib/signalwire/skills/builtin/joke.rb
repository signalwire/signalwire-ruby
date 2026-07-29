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
      class JokeSkill < SkillBase
        FALLBACK_MESSAGE = 'Sorry, there is a problem with the joke service right now. ' \
                           'Please try again later.'

        def name = 'joke'
        def description = 'Tell jokes using the API Ninjas joke API'

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
        def setup
          @api_key   = get_param('api_key', env_var: 'API_NINJAS_KEY')
          @tool_name = get_param('tool_name', default: 'get_joke')
          return false unless @api_key && !@api_key.empty?

          true
        end

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          dm = DataMap.new(tool_name)
                      .description('Get a random joke from API Ninjas')
                      .parameter('type', 'string', 'Type of joke to get', required: true, enum: %w[jokes dadjokes])
                      .webhook('GET', 'https://api.api-ninjas.com/v1/${args.type}',
                               headers: { 'X-Api-Key' => api_key })
                      .output(Swaig::FunctionResult.new("Here's a joke: ${array[0].joke}"))
                      .error_keys(%w[error])
                      .fallback_output(Swaig::FunctionResult.new(FALLBACK_MESSAGE))

          [{ datamap: dm.to_swaig_function }]
        end

        # Returns [] — this skill ships no example hints.
        def get_hints = []

        # Data this skill merges into the agent's `global_data`, so its prompts
        # and tools can reference the values as `${global_data.*}`.
        #
        # @return [Hash]
        def get_global_data
          { 'joke_skill_enabled' => true }
        end

        # The POM sections this skill contributes to the agent's prompt,
        # teaching the model when to reach for the skill's tools. Returned as
        # fresh copies, so a caller mutating them does not corrupt skill state.
        #
        # @return [Array<Hash>]
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
            "Use #{tool_name || 'get_joke'} to tell jokes when users ask for humor",
            'You can tell regular jokes or dad jokes',
            'Be enthusiastic and fun when sharing jokes'
          ]
        end
        private :joke_telling_bullets

        attr_reader :api_key, :tool_name
        private :api_key, :tool_name

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
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
