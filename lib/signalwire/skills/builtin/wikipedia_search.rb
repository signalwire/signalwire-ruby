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
        def name;        'wikipedia_search'; end
        def description; 'Search Wikipedia for information about a topic and get article summaries'; end

        def setup
          @num_results    = [1, (get_param('num_results', default: 1)).to_i].max
          @no_results_msg = get_param('no_results_message',
            default: "I couldn't find any Wikipedia articles for that query. Try rephrasing your search or using different keywords.")
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

        def get_prompt_sections
          [
            {
              'title' => 'Wikipedia Search',
              'body' => "You can search Wikipedia for factual information using search_wiki. This will return up to #{@num_results || 1} Wikipedia article summaries.",
              'bullets' => [
                'Use search_wiki for factual, encyclopedic information',
                'Great for answering questions about people, places, concepts, and history',
                'Returns reliable, well-sourced information from Wikipedia articles'
              ]
            }
          ]
        end

        def get_parameter_schema
          {
            'num_results'      => { 'type' => 'integer', 'default' => 1, 'min' => 1, 'max' => 5 },
            'no_results_message' => { 'type' => 'string' }
          }
        end

        private

        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          if query.empty?
            return Swaig::FunctionResult.new('Please provide a search query for Wikipedia.')
          end

          begin
            result = search_wiki(query)
            Swaig::FunctionResult.new(result)
          rescue => e
            Swaig::FunctionResult.new("Error searching Wikipedia: #{e.message}")
          end
        end

        def search_wiki(query)
          # Default to en.wikipedia.org host; WIKIPEDIA_BASE_URL overrides
          # for tests and the audit fixture. The env var is the *host*; the
          # `/w/api.php` path is appended below so audit_skills_dispatch
          # can match on `api.php` in req.path.
          base = ENV['WIKIPEDIA_BASE_URL']
          base = 'https://en.wikipedia.org' if base.nil? || base.empty?
          api_endpoint = "#{base.sub(/\/$/, '')}/w/api.php"

          # Step 1: Search
          search_uri = URI("#{api_endpoint}?action=query&list=search&format=json&srsearch=#{URI.encode_www_form_component(query)}&srlimit=#{@num_results}")
          search_resp = Net::HTTP.get_response(search_uri)
          return @no_results_msg unless search_resp.is_a?(Net::HTTPSuccess)

          search_data = JSON.parse(search_resp.body)
          results = search_data.dig('query', 'search') || []
          return @no_results_msg if results.empty?

          # Step 2: Get extracts. If the upstream returns extracts
          # (production behavior on en.wikipedia.org), prefer those; if the
          # response shape doesn't include `query.pages` (test fixtures,
          # truncated responses), fall back to the snippet from step 1.
          articles = results.first(@num_results).filter_map do |r|
            title = r['title']
            snippet = (r['snippet'] || '').gsub(/<[^>]+>/, '').strip
            extract_uri = URI("#{api_endpoint}?action=query&prop=extracts&exintro&explaintext&format=json&titles=#{URI.encode_www_form_component(title)}")
            extract_resp = Net::HTTP.get_response(extract_uri)

            extract = nil
            if extract_resp.is_a?(Net::HTTPSuccess)
              pages = JSON.parse(extract_resp.body).dig('query', 'pages') || {}
              page = pages.values.first
              extract = page&.dig('extract')&.strip
            end

            content = extract && !extract.empty? ? extract : snippet
            next if content.nil? || content.empty?

            "**#{title}**\n\n#{content}"
          end

          return @no_results_msg if articles.empty?
          articles.join("\n\n#{'=' * 50}\n\n")
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('wikipedia_search') do |params|
  SignalWire::Skills::Builtin::WikipediaSearchSkill.new(params)
end
