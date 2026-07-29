# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # Fetch trivia questions from API Ninjas as a DataMap tool — the request runs
      # ON SignalWire's servers, so there is no webhook back to this agent. Requires
      # an `API_NINJAS_KEY` (or an `api_key` param).
      class ApiNinjasTriviaSkill < SkillBase
        VALID_CATEGORIES = {
          'artliterature' => 'Art and Literature',
          'language' => 'Language',
          'sciencenature' => 'Science and Nature',
          'general' => 'General Knowledge',
          'fooddrink' => 'Food and Drink',
          'peopleplaces' => 'People and Places',
          'geography' => 'Geography',
          'historyholidays' => 'History and Holidays',
          'entertainment' => 'Entertainment',
          'toysgames' => 'Toys and Games',
          'music' => 'Music',
          'mathematics' => 'Mathematics',
          'religionmythology' => 'Religion and Mythology',
          'sportsleisure' => 'Sports and Leisure'
        }.freeze

        # The name this skill is added under (`agent.add_skill('api_ninjas_trivia')`).
        #
        # @return [String]
        def name = 'api_ninjas_trivia'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Get trivia questions from API Ninjas'
        # This skill may be loaded more than once on one agent — each instance
        # is distinguished by its `prefix` param, which also namespaces its
        # tools and its slice of `global_data`.
        #
        # @return [Boolean] true
        def supports_multiple_instances? = true

        # Extracts the configuration (tool_name / api_key / categories) off
        # ``params`` at construction time so the ivars exist immediately.
        # {#setup} re-reads them (and returns the validation bool).
        def initialize(agent = nil, params = nil)
          super
          @tool_name  = get_param('tool_name', default: 'get_trivia')
          @api_key    = get_param('api_key', env_var: 'API_NINJAS_KEY')
          @categories = get_param('categories') || VALID_CATEGORIES.keys
        end

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
        def setup
          @api_key    = get_param('api_key', env_var: 'API_NINJAS_KEY')
          @tool_name  = get_param('tool_name', default: 'get_trivia')
          @categories = get_param('categories') || VALID_CATEGORIES.keys

          return false unless @api_key && !@api_key.empty?
          return false unless @categories.is_a?(Array) && !@categories.empty?

          true
        end

        # The key this instance is tracked under — `api_ninjas_trivia_<tool_name>` — so several
        # instances can coexist on one agent without colliding.
        #
        # @return [String]
        def instance_key = "api_ninjas_trivia_#{@tool_name}"

        # Returns the raw SWAIG tool DEFINITION hashes (the DataMap tool the
        # skill provides). {#register_tools} builds on top of this.
        def get_tools
          [
            {
              'function' => @tool_name,
              'description' => "Get trivia questions for #{@tool_name.tr('_', ' ')}",
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

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
        def get_parameter_schema
          {
            'api_key' => { 'type' => 'string', 'required' => true, 'hidden' => true, 'env_var' => 'API_NINJAS_KEY' },
            'categories' => { 'type' => 'array', 'default' => VALID_CATEGORIES.keys }
          }
        end

        private

        # @api private — the tool's JSON Schema: one required `category`, constrained
        # to the configured category list so the model cannot invent one the API would
        # reject.
        #
        # @return [Hash]
        def tool_parameters
          {
            'type' => 'object',
            'properties' => {
              'category' => { 'type' => 'string', 'description' => category_param_desc, 'enum' => @categories }
            },
            'required' => ['category']
          }
        end

        # @api private — the category parameter's description, spelling out every
        # configured category and what it covers, so the model can pick from the
        # description alone.
        #
        # @return [String]
        def category_param_desc
          descs = @categories.map { |c| "#{c}: #{VALID_CATEGORIES[c] || c}" }
          "Category for trivia question. Options: #{descs.join('; ')}"
        end

        # Default to the production endpoint; API_NINJAS_BASE_URL overrides
        # the host (the audit fixture sets it to a loopback address). The
        # `/v1/trivia` path is preserved so the audit can match on `trivia`
        # in the fixture's req.path.
        def base_url
          base = ENV.fetch('API_NINJAS_BASE_URL', nil)
          base = 'https://api.api-ninjas.com' if base.nil? || base.empty?
          base.sub(%r{/$}, '')
        end

        # @api private — the DataMap: the trivia webhook, `error` as the failure key,
        # and a spoken fallback used when the request fails.
        #
        # @return [Hash]
        def tool_data_map
          {
            'webhooks' => [trivia_webhook],
            'error_keys' => ['error'],
            'output' => Swaig::FunctionResult.new(
              'Sorry, I cannot get trivia questions right now. Please try again later.'
            ).to_h
          }
        end

        # @api private — the API Ninjas request the platform issues, with the key in
        # the `X-Api-Key` header. The output template reads the first array element and
        # explicitly tells the model to pause before revealing the answer.
        #
        # @return [Hash]
        def trivia_webhook
          output = Swaig::FunctionResult.new(
            'Category %{array[0].category} question: %{array[0].question} ' \
            'Answer: %{array[0].answer}, be sure to give the user time to answer before saying the answer.'
          ).to_h
          {
            'url' => "#{base_url}/v1/trivia?category=%{args.category}",
            'method' => 'GET',
            'headers' => { 'X-Api-Key' => @api_key },
            'output' => output
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('api_ninjas_trivia') do |params|
  SignalWire::Skills::Builtin::ApiNinjasTriviaSkill.new(params)
end
