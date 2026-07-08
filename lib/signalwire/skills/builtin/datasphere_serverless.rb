# frozen_string_literal: true

require 'base64'

require_relative '../skill_base'
require_relative '../skill_registry'
require_relative '../../datamap/data_map'

module SignalWire
  module Skills
    module Builtin
      class DatasphereServerlessSkill < SkillBase
        def name = 'datasphere_serverless'
        def description = 'Search knowledge using SignalWire DataSphere with serverless DataMap execution'
        def supports_multiple_instances? = true

        def setup
          load_params
          return false unless required_params_present?

          @api_url     = "https://#{@space_name}.signalwire.com/api/datasphere/documents/search"
          @auth_header = Base64.strict_encode64("#{@project_id}:#{@token}")
          true
        end

        def instance_key = "datasphere_serverless_#{@tool_name}"

        def register_tools
          dm = DataMap.new(@tool_name)
                      .description('Search the knowledge base for information on any topic and return relevant results')
                      .parameter('query', 'string', 'The search query', required: true)
                      .webhook('POST', @api_url, headers: webhook_headers)
                      .params(search_params)
                      .foreach(foreach_config)
                      .output(Swaig::FunctionResult.new('I found results for "${args.query}":\n\n${formatted_results}'))
                      .error_keys(%w[error])
                      .fallback_output(Swaig::FunctionResult.new(@no_results_msg))

          [{ datamap: dm.to_swaig_function }]
        end

        # Returns [] — this skill ships no example hints.
        def get_hints = []

        def get_global_data
          {
            'datasphere_serverless_enabled' => true,
            'document_id' => @document_id,
            'knowledge_provider' => 'SignalWire DataSphere (Serverless)'
          }
        end

        def get_prompt_sections
          [
            {
              'title' => 'Knowledge Search Capability (Serverless)',
              'body' => "You can search a knowledge base for information using the #{@tool_name} tool.",
              'bullets' => prompt_bullets
            }
          ]
        end

        def get_parameter_schema
          {
            'space_name' => { 'type' => 'string', 'required' => true },
            'project_id' => { 'type' => 'string', 'required' => true },
            'token' => { 'type' => 'string', 'required' => true, 'hidden' => true },
            'document_id' => { 'type' => 'string', 'required' => true },
            'count' => { 'type' => 'integer', 'default' => 1 },
            'distance' => { 'type' => 'number', 'default' => 3.0 }
          }
        end

        private

        def load_params
          @space_name  = get_param('space_name')
          @project_id  = get_param('project_id', env_var: 'SIGNALWIRE_PROJECT_ID')
          @token       = get_param('token', env_var: 'SIGNALWIRE_TOKEN')
          @document_id = get_param('document_id')
          @count       = get_param('count', default: 1).to_i
          @distance    = get_param('distance', default: 3.0).to_f
          @tool_name   = get_param('tool_name', default: 'search_knowledge')
          @no_results_msg = get_param('no_results_message',
                                      default: "I couldn't find any relevant information in the knowledge base.")
        end

        def prompt_bullets
          [
            "Use the #{@tool_name} tool when users ask for information",
            'Search for relevant information using clear, specific queries',
            'Summarize search results in a clear, helpful way',
            'This tool executes on SignalWire servers for optimal performance'
          ]
        end

        def required_params_present?
          %w[space_name project_id token document_id].all? do |k|
            v = instance_variable_get("@#{k}")
            !v.nil? && !v.to_s.empty?
          end
        end

        def webhook_headers
          {
            'Content-Type' => 'application/json',
            'Authorization' => "Basic #{@auth_header}"
          }
        end

        def search_params
          {
            'document_id' => @document_id,
            'query_string' => '${args.query}',
            'count' => @count,
            'distance' => @distance
          }
        end

        def foreach_config
          {
            'input_key' => 'chunks',
            'output_key' => 'formatted_results',
            'max' => @count,
            'append' => "=== RESULT ===\n${this.text}\n#{'=' * 50}\n\n"
          }
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('datasphere_serverless') do |params|
  SignalWire::Skills::Builtin::DatasphereServerlessSkill.new(params)
end
