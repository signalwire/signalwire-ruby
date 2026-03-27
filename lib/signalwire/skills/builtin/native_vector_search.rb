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
        def name;        'native_vector_search'; end
        def description; 'Search document indexes using vector similarity and keyword search (local or remote)'; end
        def supports_multiple_instances?; true; end

        def setup
          @remote_url  = get_param('remote_url')
          @index_name  = get_param('index_name')
          @tool_name   = get_param('tool_name', default: 'search_knowledge')
          @tool_desc   = get_param('description', default: 'Search the local knowledge base for information')
          @count       = (get_param('count', default: 3)).to_i
          @threshold   = (get_param('similarity_threshold', default: 0.5)).to_f
          @custom_hints = get_param('hints') || []

          # Network mode requires remote_url
          return false unless @remote_url && !@remote_url.empty?
          true
        end

        def instance_key; "native_vector_search_#{@tool_name}"; end

        def register_tools
          [
            {
              name: @tool_name,
              description: @tool_desc,
              parameters: {
                'query' => { 'type' => 'string', 'description' => 'Search query' },
                'count' => { 'type' => 'integer', 'description' => 'Number of results to return' }
              },
              handler: method(:handle_search)
            }
          ]
        end

        def get_hints
          base = %w[search find look\ up documentation knowledge\ base]
          base.concat(@custom_hints) if @custom_hints.is_a?(Array)
          base
        end

        def get_parameter_schema
          {
            'remote_url'           => { 'type' => 'string', 'required' => true },
            'index_name'           => { 'type' => 'string' },
            'count'                => { 'type' => 'integer', 'default' => 3 },
            'similarity_threshold' => { 'type' => 'number', 'default' => 0.5 },
            'description'          => { 'type' => 'string' },
            'hints'                => { 'type' => 'array' }
          }
        end

        private

        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          return Swaig::FunctionResult.new('Please provide a search query.') if query.empty?

          count = (args['count'] || @count).to_i

          begin
            uri = URI(@remote_url)
            params = { query: query, count: count }
            params[:index_name] = @index_name if @index_name

            req = Net::HTTP::Post.new(uri.path.empty? ? '/' : uri.path)
            req['Content-Type'] = 'application/json'
            req.body = params.to_json

            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == 'https')
            http.open_timeout = 10
            http.read_timeout = 30

            resp = http.request(req)
            unless resp.is_a?(Net::HTTPSuccess)
              return Swaig::FunctionResult.new('Sorry, the search service is unavailable right now.')
            end

            data = JSON.parse(resp.body)
            results = data['results'] || data['chunks'] || []
            if results.empty?
              return Swaig::FunctionResult.new("No results found for '#{query}'.")
            end

            formatted = results.first(count).each_with_index.map do |r, i|
              text = r['text'] || r['content'] || r.to_json
              "=== RESULT #{i + 1} ===\n#{text}\n#{'=' * 50}"
            end.join("\n\n")

            Swaig::FunctionResult.new("Search results for '#{query}':\n\n#{formatted}")
          rescue => e
            Swaig::FunctionResult.new("Error searching: #{e.message}")
          end
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('native_vector_search') do |params|
  SignalWire::Skills::Builtin::NativeVectorSearchSkill.new(params)
end
