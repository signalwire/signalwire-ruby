# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      # Network/remote mode only (as per porting manifest).
      class NativeVectorSearchSkill < SkillBase
        def name = 'native_vector_search'
        def description = 'Search document indexes using vector similarity and keyword search (local or remote)'
        def supports_multiple_instances? = true

        def setup
          @remote_url  = get_param('remote_url')
          @index_name  = get_param('index_name')
          @tool_name   = get_param('tool_name', default: 'search_knowledge')
          @tool_desc   = get_param('description', default: 'Search the local knowledge base for information')
          @count       = get_param('count', default: 3).to_i
          @threshold   = get_param('similarity_threshold', default: 0.5).to_f
          @custom_hints = get_param('hints') || []

          # Network mode requires remote_url
          return false unless @remote_url && !@remote_url.empty?

          true
        end

        def instance_key = "native_vector_search_#{@tool_name}"

        TOOL_PARAMETERS = {
          'query' => { 'type' => 'string', 'description' => 'Search query' },
          'count' => { 'type' => 'integer', 'description' => 'Number of results to return' }
        }.freeze

        def register_tools
          [{ name: @tool_name, description: @tool_desc,
             parameters: TOOL_PARAMETERS, handler: method(:handle_search) }]
        end

        def get_hints
          base = ['search', 'find', 'look up', 'documentation', 'knowledge base']
          base.concat(@custom_hints) if @custom_hints.is_a?(Array)
          base
        end

        def get_parameter_schema
          {
            'remote_url' => { 'type' => 'string', 'required' => true },
            'index_name' => { 'type' => 'string' },
            'count' => { 'type' => 'integer', 'default' => 3 },
            'similarity_threshold' => { 'type' => 'number', 'default' => 0.5 },
            'description' => { 'type' => 'string' },
            'hints' => { 'type' => 'array' }
          }
        end

        private

        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          return Swaig::FunctionResult.new('Please provide a search query.') if query.empty?

          count = (args['count'] || @count).to_i
          resp = post_search(query, count)
          unless resp.is_a?(Net::HTTPSuccess)
            return Swaig::FunctionResult.new('Sorry, the search service is unavailable right now.')
          end

          format_results(JSON.parse(resp.body), query, count)
        rescue StandardError => e
          Swaig::FunctionResult.new("Error searching: #{e.message}")
        end

        def post_search(query, count)
          # Python parity: POST to "<remote_base_url>/search" (the remote_url is
          # a base URL; the /search endpoint is appended).
          uri = URI(search_endpoint)
          params = { query: query, count: count, similarity_threshold: @threshold }
          params[:index_name] = @index_name if @index_name

          req = Net::HTTP::Post.new(uri.request_uri)
          req['Content-Type'] = 'application/json'
          req.body = params.to_json
          search_http(uri).request(req)
        end

        # Build "<remote_url>/search", collapsing any duplicate slash between
        # the base and the endpoint.
        def search_endpoint
          "#{@remote_url.chomp('/')}/search"
        end

        def search_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = 10
          http.read_timeout = 30
          http
        end

        def format_results(data, query, count)
          results = data['results'] || data['chunks'] || []
          return Swaig::FunctionResult.new("No results found for '#{query}'.") if results.empty?

          formatted = results.first(count).each_with_index.map do |r, i|
            text = r['text'] || r['content'] || r.to_json
            "=== RESULT #{i + 1} ===\n#{text}\n#{'=' * 50}"
          end.join("\n\n")

          Swaig::FunctionResult.new("Search results for '#{query}':\n\n#{formatted}")
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('native_vector_search') do |params|
  SignalWire::Skills::Builtin::NativeVectorSearchSkill.new(params)
end
