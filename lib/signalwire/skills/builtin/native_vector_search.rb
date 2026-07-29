# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Skills — the modular capability framework: skill base, registry, manager, builtins.
  module Skills
    # Builtin — the skills that ship with the SDK, registered by name at load time.
    module Builtin
      # Network/remote mode only (as per porting manifest).
      class NativeVectorSearchSkill < SkillBase
        # The name this skill is added under (`agent.add_skill('native_vector_search')`).
        #
        # @return [String]
        def name = 'native_vector_search'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Search document indexes using vector similarity and keyword search (local or remote)'
        # This skill may be loaded more than once on one agent — each instance
        # is distinguished by its `prefix` param, which also namespaces its
        # tools and its slice of `global_data`.
        #
        # @return [Boolean] true
        def supports_multiple_instances? = true

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
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

        # The key this instance is tracked under — `native_vector_search_<tool_name>` — so several
        # instances can coexist on one agent without colliding.
        #
        # @return [String]
        def instance_key = "native_vector_search_#{@tool_name}"

        TOOL_PARAMETERS = {
          'query' => { 'type' => 'string', 'description' => 'Search query' },
          'count' => { 'type' => 'integer', 'description' => 'Number of results to return' }
        }.freeze

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          [{ name: @tool_name, description: @tool_desc,
             parameters: TOOL_PARAMETERS, handler: method(:handle_search) }]
        end

        # Speech-recognition hints this skill contributes to the AI verb, biasing
        # the recognizer toward the vocabulary the skill's domain uses.
        #
        # @return [Array<String>]
        def get_hints
          base = ['search', 'find', 'look up', 'documentation', 'knowledge base']
          base.concat(@custom_hints) if @custom_hints.is_a?(Array)
          base
        end

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
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

        # @api private — the search handler. The per-call `count` argument overrides
        # the configured default. An empty query, an unavailable service, or a raised
        # error each become a spoken FunctionResult rather than an exception.
        #
        # @return [Swaig::FunctionResult]
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

        # @api private — POST the query, result count and similarity threshold to the
        # search service's `/search` endpoint, adding `index_name` when one is
        # configured.
        #
        # @return [Net::HTTPResponse]
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

        # @api private — the Net::HTTP transport for the search endpoint, with TLS on
        # for an https scheme and 10s connect / 30s read timeouts so a hung index
        # server cannot stall the SWAIG handler indefinitely.
        #
        # @return [Net::HTTP]
        def search_http(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = 10
          http.read_timeout = 30
          http
        end

        # @api private — render the search response as numbered, delimited blocks.
        # Results arrive under `results` or `chunks` depending on the backend, and each
        # item's text under `text` or `content`, so both shapes are accepted; an
        # unrecognised item falls back to its raw JSON rather than being dropped.
        #
        # @return [Swaig::FunctionResult]
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
