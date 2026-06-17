# frozen_string_literal: true

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
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

        def name = 'api_ninjas_trivia'
        def description = 'Get trivia questions from API Ninjas'
        def supports_multiple_instances? = true

        def setup
          @api_key    = get_param('api_key', env_var: 'API_NINJAS_KEY')
          @tool_name  = get_param('tool_name', default: 'get_trivia')
          @categories = get_param('categories') || VALID_CATEGORIES.keys

          return false unless @api_key && !@api_key.empty?
          return false unless @categories.is_a?(Array) && !@categories.empty?

          true
        end

        def instance_key = "api_ninjas_trivia_#{@tool_name}"

        def register_tools
          descs = @categories.map { |c| "#{c}: #{VALID_CATEGORIES[c] || c}" }
          param_desc = 'Category for trivia question. Options: ' + descs.join('; ')

          # Default to the production endpoint; API_NINJAS_BASE_URL
          # overrides the host (the audit fixture sets it to a loopback
          # address). The `/v1/trivia` path is preserved so the audit
          # can match on `trivia` in the fixture's req.path.
          base = ENV.fetch('API_NINJAS_BASE_URL', nil)
          base = 'https://api.api-ninjas.com' if base.nil? || base.empty?
          base = base.sub(%r{/$}, '')

          tool = {
            'function' => @tool_name,
            'description' => "Get trivia questions for #{@tool_name.tr('_', ' ')}",
            'parameters' => {
              'type' => 'object',
              'properties' => {
                'category' => { 'type' => 'string', 'description' => param_desc, 'enum' => @categories }
              },
              'required' => ['category']
            },
            'data_map' => {
              'webhooks' => [
                {
                  'url' => "#{base}/v1/trivia?category=%{args.category}",
                  'method' => 'GET',
                  'headers' => { 'X-Api-Key' => @api_key },
                  'output' => Swaig::FunctionResult.new(
                    'Category %{array[0].category} question: %{array[0].question} Answer: %{array[0].answer}, be sure to give the user time to answer before saying the answer.'
                  ).to_h
                }
              ],
              'error_keys' => ['error'],
              'output' => Swaig::FunctionResult.new(
                'Sorry, I cannot get trivia questions right now. Please try again later.'
              ).to_h
            }
          }

          [{ datamap: tool }]
        end

        def get_parameter_schema
          {
            'api_key' => { 'type' => 'string', 'required' => true, 'hidden' => true, 'env_var' => 'API_NINJAS_KEY' },
            'categories' => { 'type' => 'array', 'default' => VALID_CATEGORIES.keys }
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('api_ninjas_trivia') do |params|
  SignalWire::Skills::Builtin::ApiNinjasTriviaSkill.new(params)
end
