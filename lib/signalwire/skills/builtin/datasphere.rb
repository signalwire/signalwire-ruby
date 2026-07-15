# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'base64'

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      # Private mixin holding {DatasphereSkill}'s param parsing, URL building,
      # search HTTP call, and response formatting. Extracted purely to keep the
      # skill class within the size budget; every method is private and reads
      # the skill's ivars.
      module DatasphereSearch
        DEFAULT_NO_RESULTS_MESSAGE =
          "I couldn't find any relevant information in the knowledge base. " \
          'Try rephrasing your question.'

        private

        def read_params
          @space_name  = get_param('space_name')
          @project_id  = get_param('project_id', env_var: 'SIGNALWIRE_PROJECT_ID')
          @token       = get_param('token', env_var: 'SIGNALWIRE_TOKEN')
          @document_id = get_param('document_id')
          @count       = get_param('count', default: 1).to_i
          @distance    = get_param('distance', default: 3.0).to_f
          @tool_name   = get_param('tool_name', default: 'search_knowledge')
          @tags        = get_param('tags')
          @no_results_msg = get_param('no_results_message', default: DEFAULT_NO_RESULTS_MESSAGE)
        end

        def prompt_section_bullets
          [
            "Use the #{tool_name} tool when users ask for information that might be in the knowledge base",
            'Search for relevant information using clear, specific queries',
            'Summarize search results in a clear, helpful way',
            'If no results are found, suggest the user try rephrasing their question'
          ]
        end

        # Default to {space}.signalwire.com host; DATASPHERE_BASE_URL overrides
        # the host (the `/api/datasphere/...` path is preserved so the audit
        # can match on `datasphere` in req.path).
        def datasphere_host_url
          resolved_base_url('DATASPHERE_BASE_URL', "https://#{space_name}.signalwire.com")
        end

        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          return Swaig::FunctionResult.new('Please provide a search query.') if query.empty?

          resp = post_search(query)
          unless resp.is_a?(Net::HTTPSuccess)
            return Swaig::FunctionResult.new('Sorry, there was an error accessing the knowledge base.')
          end

          format_search_response(JSON.parse(resp.body), query)
        rescue StandardError => e
          Swaig::FunctionResult.new("Error searching knowledge base: #{e.message}")
        end

        def post_search(query)
          payload = {
            'document_id' => document_id, 'query_string' => query,
            'distance' => distance, 'count' => count
          }
          payload['tags'] = tags if tags

          uri = URI(api_url)
          http_for(uri).request(build_search_request(uri, payload))
        end

        def http_for(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http
        end

        def build_search_request(uri, payload)
          req = Net::HTTP::Post.new(uri.path)
          req['Content-Type'] = 'application/json'
          req['Accept']       = 'application/json'
          req.basic_auth(project_id, token)
          req.body = payload.to_json
          req
        end

        def format_search_response(data, query)
          # Real DataSphere uses `chunks`; audit fixtures also serve `results`
          # (real-shape upstream-response variation). Accept both shapes.
          chunks = data['chunks'] || data['results'] || []
          return Swaig::FunctionResult.new(no_results_msg) if chunks.empty?

          Swaig::FunctionResult.new(
            "I found #{chunks.size} result(s) for '#{query}':\n\n#{format_chunks(chunks)}"
          )
        end

        def format_chunks(chunks)
          chunks.each_with_index.map do |chunk, i|
            text = chunk['text'] || chunk['content'] || chunk['chunk'] || chunk.to_json
            "=== RESULT #{i + 1} ===\n#{text}\n#{'=' * 50}"
          end.join("\n\n")
        end
      end

      class DatasphereSkill < SkillBase
        include DatasphereSearch

        TOOL_DESCRIPTION =
          'Search the knowledge base for information on any topic and return relevant results'

        def name = 'datasphere'
        def description = 'Search knowledge using SignalWire DataSphere RAG stack'
        def supports_multiple_instances? = true

        def setup
          read_params

          %w[space_name project_id token document_id].each do |k|
            return false if instance_variable_get("@#{k}").nil? || instance_variable_get("@#{k}").to_s.empty?
          end

          @api_url = "#{datasphere_host_url}/api/datasphere/documents/search"
          true
        end

        def instance_key = "datasphere_#{tool_name}"

        # Tears down the skill. A fresh Net::HTTP connection is opened per
        # request (no persistent session to close), so teardown drops the
        # cached search endpoint and logs that the skill was cleaned up.
        # Safe to call more than once (idempotent).
        def cleanup
          @api_url = nil
          logger.info('DataSphere skill cleaned up')
          nil
        end

        def register_tools
          [
            {
              name: tool_name,
              description: TOOL_DESCRIPTION,
              parameters: {
                'query' => { 'type' => 'string', 'description' => 'The search query' }
              },
              handler: method(:handle_search)
            }
          ]
        end

        # Returns [] — this skill ships no example hints.
        def get_hints = []

        def get_global_data
          {
            'datasphere_enabled' => true,
            'document_id' => document_id,
            'knowledge_provider' => 'SignalWire DataSphere'
          }
        end

        def get_prompt_sections
          [
            {
              'title' => 'Knowledge Search Capability',
              'body' => "You can search a knowledge base for information using the #{tool_name} tool.",
              'bullets' => prompt_section_bullets
            }
          ]
        end

        def get_parameter_schema
          {
            'space_name' => { 'type' => 'string', 'required' => true },
            'project_id' => { 'type' => 'string', 'required' => true, 'env_var' => 'SIGNALWIRE_PROJECT_ID' },
            'token' => { 'type' => 'string', 'required' => true, 'hidden' => true,
                         'env_var' => 'SIGNALWIRE_TOKEN' },
            'document_id' => { 'type' => 'string', 'required' => true },
            'count' => { 'type' => 'integer', 'default' => 1, 'min' => 1, 'max' => 10 },
            'distance' => { 'type' => 'number', 'default' => 3.0 }
          }
        end

        private

        attr_reader :space_name, :project_id, :token, :document_id, :count,
                    :distance, :tool_name, :tags, :no_results_msg, :api_url
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('datasphere') do |params|
  SignalWire::Skills::Builtin::DatasphereSkill.new(params)
end
