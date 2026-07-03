# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class WikipediaSearchSkill < SkillBase
        def name = 'wikipedia_search'
        def description = 'Search Wikipedia for information about a topic and get article summaries'

        DEFAULT_NO_RESULTS_MSG = "I couldn't find any Wikipedia articles for that query. " \
                                 'Try rephrasing your search or using different keywords.'

        def setup
          @num_results    = [1, get_param('num_results', default: 1).to_i].max
          @no_results_msg = get_param('no_results_message', default: DEFAULT_NO_RESULTS_MSG)
          true
        end

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

        # Python parity: ``WikipediaSearchSkill.get_hints`` returns [] (the
        # reference documents optional example hints in a comment but ships
        # none).
        def get_hints = []

        def get_prompt_sections
          body = 'You can search Wikipedia for factual information using search_wiki. ' \
                 "This will return up to #{@num_results || 1} Wikipedia article summaries."
          bullets = [
            'Use search_wiki for factual, encyclopedic information',
            'Great for answering questions about people, places, concepts, and history',
            'Returns reliable, well-sourced information from Wikipedia articles'
          ]
          [{ 'title' => 'Wikipedia Search', 'body' => body, 'bullets' => bullets }]
        end

        def get_parameter_schema
          {
            'num_results' => { 'type' => 'integer', 'default' => 1, 'min' => 1, 'max' => 5 },
            'no_results_message' => { 'type' => 'string' }
          }
        end

        # Python parity: ``WikipediaSearchSkill.search_wiki(query)`` — the
        # extracted helper that performs the two-step Wikipedia API lookup
        # (search, then per-title extract) and returns the formatted article
        # text (or the no-results message). Public so callers/tests can invoke
        # the lookup directly, matching Python where the tool handler delegates
        # to this method. ``@num_results``/``@no_results_msg`` are populated by
        # #setup; fall back to defaults if called before setup.
        def search_wiki(query)
          @num_results    ||= 1
          @no_results_msg ||= DEFAULT_NO_RESULTS_MSG

          results = wiki_search_results(query)
          return @no_results_msg if results.nil? || results.empty?

          articles = results.first(@num_results).filter_map { |r| article_for(r) }
          return @no_results_msg if articles.empty?

          articles.join("\n\n#{'=' * 50}\n\n")
        end

        private

        # Default to en.wikipedia.org host; WIKIPEDIA_BASE_URL overrides
        # for tests and the audit fixture. The env var is the *host*; the
        # `/w/api.php` path is appended so audit_skills_dispatch can match
        # on `api.php` in req.path.
        def api_endpoint
          base = ENV.fetch('WIKIPEDIA_BASE_URL', nil)
          base = 'https://en.wikipedia.org' if base.nil? || base.empty?
          "#{base.sub(%r{/$}, '')}/w/api.php"
        end

        # Step 1: Search. Returns the list of result hashes, or nil if the
        # upstream request failed.
        def wiki_search_results(query)
          search_uri = URI(
            "#{api_endpoint}?action=query&list=search&format=json" \
            "&srsearch=#{URI.encode_www_form_component(query)}&srlimit=#{@num_results}"
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
