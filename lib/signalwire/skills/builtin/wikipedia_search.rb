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
      # Search Wikipedia and hand the model an article summary. Two upstream calls:
      # a search for matching titles, then an intro-extract for each. Needs no
      # credentials — the MediaWiki API is public.
      class WikipediaSearchSkill < SkillBase
        # The name this skill is added under (`agent.add_skill('wikipedia_search')`).
        #
        # @return [String]
        def name = 'wikipedia_search'
        # Human-readable summary of what the skill does, for skill listings.
        #
        # @return [String]
        def description = 'Search Wikipedia for information about a topic and get article summaries'

        DEFAULT_NO_RESULTS_MSG = "I couldn't find any Wikipedia articles for that query. " \
                                 'Try rephrasing your search or using different keywords.'

        # Called once after construction. Return false to abort loading — the
        # agent then refuses to register this skill's tools.
        #
        # @return [Boolean] true when the skill is ready to run
        def setup
          @num_results    = [1, get_param('num_results', default: 1).to_i].max
          @no_results_msg = get_param('no_results_message', default: DEFAULT_NO_RESULTS_MSG)
          true
        end

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          [
            {
              name: 'search_wiki',
              description: 'Search Wikipedia for information about a topic and get article summaries',
              parameters: {
                'query' => { 'type' => 'string', 'description' => 'The search term or topic to look up on Wikipedia' }
              },
              handler: method(:handle_search)
            }
          ]
        end

        # Returns [] — this skill ships no example hints.
        def get_hints = []

        # The POM sections this skill contributes to the agent's prompt,
        # teaching the model when to reach for the skill's tools. Returned as
        # fresh copies, so a caller mutating them does not corrupt skill state.
        #
        # @return [Array<Hash>]
        def get_prompt_sections
          body = 'You can search Wikipedia for factual information using search_wiki. ' \
                 "This will return up to #{num_results} Wikipedia article summaries."
          bullets = [
            'Use search_wiki for factual, encyclopedic information',
            'Great for answering questions about people, places, concepts, and history',
            'Returns reliable, well-sourced information from Wikipedia articles'
          ]
          [{ 'title' => 'Wikipedia Search', 'body' => body, 'bullets' => bullets }]
        end

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
        def get_parameter_schema
          {
            'num_results' => { 'type' => 'integer', 'default' => 1, 'min' => 1, 'max' => 5 },
            'no_results_message' => { 'type' => 'string' }
          }
        end

        # The helper that performs the two-step Wikipedia API lookup
        # (search, then per-title extract) and returns the formatted article
        # text (or the no-results message). Public so callers/tests can invoke
        # the lookup directly; the tool handler delegates to this method.
        # #num_results / #no_results_msg fall back to defaults if read before
        # #setup populates their ivars.
        def search_wiki(query)
          results = wiki_search_results(query)
          return no_results_msg if results.nil? || results.empty?

          articles = results.first(num_results).filter_map { |r| article_for(r) }
          return no_results_msg if articles.empty?

          articles.join("\n\n#{'=' * 50}\n\n")
        end

        private

        # Populated by #setup; fall back to defaults if read before setup.
        def num_results
          return @num_results if defined?(@num_results) && @num_results

          @num_results = 1
        end

        # @api private — the message spoken when nothing matched, memoized from the
        # config with a default so it is usable before {#setup} has run.
        #
        # @return [String]
        def no_results_msg
          return @no_results_msg if defined?(@no_results_msg) && @no_results_msg

          @no_results_msg = DEFAULT_NO_RESULTS_MSG
        end

        # Default to en.wikipedia.org host; WIKIPEDIA_BASE_URL overrides
        # for tests and the audit fixture. The env var is the *host*; the
        # The `/w/api.php` path is appended so the skills-dispatch audit can
        # match on `api.php` in the request path.
        def api_endpoint
          "#{resolved_base_url('WIKIPEDIA_BASE_URL', 'https://en.wikipedia.org')}/w/api.php"
        end

        # Step 1: Search. Returns the list of result hashes, or nil if the
        # upstream request failed.
        def wiki_search_results(query)
          search_uri = URI(
            "#{api_endpoint}?action=query&list=search&format=json" \
            "&srsearch=#{URI.encode_www_form_component(query)}&srlimit=#{num_results}"
          )
          search_resp = Net::HTTP.get_response(search_uri)
          return nil unless search_resp.is_a?(Net::HTTPSuccess)

          JSON.parse(search_resp.body).dig('query', 'search') || []
        end

        # Step 2: Get the extract for one result. If the upstream returns
        # extracts (production behavior on en.wikipedia.org), prefer those;
        # if the response shape doesn't include `query.pages` (test fixtures,
        # truncated responses), fall back to the snippet from step 1.
        def article_for(result)
          title = result['title']
          snippet = (result['snippet'] || '').gsub(/<[^>]+>/, '').strip
          extract = wiki_extract(title)

          content = extract && !extract.empty? ? extract : snippet
          return nil if content.nil? || content.empty?

          "**#{title}**\n\n#{content}"
        end

        # @api private — the plain-text intro extract for one article title. A non-2xx
        # response or a body without `query.pages` yields nil, and the caller falls
        # back to the search snippet.
        #
        # @return [String, nil]
        def wiki_extract(title)
          extract_uri = URI(
            "#{api_endpoint}?action=query&prop=extracts&exintro&explaintext&format=json" \
            "&titles=#{URI.encode_www_form_component(title)}"
          )
          extract_resp = Net::HTTP.get_response(extract_uri)
          return nil unless extract_resp.is_a?(Net::HTTPSuccess)

          pages = JSON.parse(extract_resp.body).dig('query', 'pages') || {}
          pages.values.first&.dig('extract')&.strip
        end

        # @api private — the search handler. An empty query or a raised error each
        # become a spoken FunctionResult rather than an exception.
        #
        # @return [Swaig::FunctionResult]
        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          return Swaig::FunctionResult.new('Please provide a search query for Wikipedia.') if query.empty?

          begin
            result = search_wiki(query)
            Swaig::FunctionResult.new(result)
          rescue StandardError => e
            Swaig::FunctionResult.new("Error searching Wikipedia: #{e.message}")
          end
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('wikipedia_search') do |params|
  SignalWire::Skills::Builtin::WikipediaSearchSkill.new(params)
end
