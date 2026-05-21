# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class WebSearchSkill < SkillBase
        def name;        'web_search'; end
        def description; 'Search the web for information using Google Custom Search API'; end
        def version;     '2.0.0'; end
        def supports_multiple_instances?; true; end

        def setup
          @api_key           = get_param('api_key', env_var: 'GOOGLE_SEARCH_API_KEY')
          @search_engine_id  = get_param('search_engine_id', env_var: 'GOOGLE_SEARCH_ENGINE_ID')
          @num_results       = (get_param('num_results', default: 3)).to_i
          @tool_name         = get_param('tool_name', default: 'web_search')
          @no_results_msg    = get_param('no_results_message',
            default: "I couldn't find quality results for that query. Try rephrasing your search.")

          # Optional prefix/postfix wrapped around every non-empty search
          # result. Use these to give the calling agent a mechanical cue
          # (e.g. "tell the user this came from a public web search")
          # without needing prompt-side rules. Mirrors Python parity.
          @response_prefix   = get_param('response_prefix',  default: '')
          @response_postfix  = get_param('response_postfix', default: '')

          return false unless @api_key && !@api_key.empty?
          return false unless @search_engine_id && !@search_engine_id.empty?
          true
        end

        def instance_key; "web_search_#{@tool_name}"; end

        def register_tools
          [
            {
              name: @tool_name,
              description: 'Search the web for high-quality information, automatically filtering low-quality results',
              parameters: {
                'query' => { 'type' => 'string', 'description' => 'The search query - what you want to find information about' }
              },
              handler: method(:handle_search)
            }
          ]
        end

        def get_global_data
          { 'web_search_enabled' => true, 'search_provider' => 'Google Custom Search', 'quality_filtering' => true }
        end

        def get_prompt_sections
          [
            {
              'title' => 'Web Search Capability (Quality Enhanced)',
              'body' => "You can search the internet for high-quality information using the #{@tool_name} tool.",
              'bullets' => [
                "Use the #{@tool_name} tool when users ask for information you need to look up",
                'The search automatically filters out low-quality results like empty pages',
                'Results are ranked by content quality, relevance, and domain reputation',
                'Summarize the high-quality results in a clear, helpful way'
              ]
            }
          ]
        end

        def get_parameter_schema
          {
            'api_key'          => { 'type' => 'string', 'required' => true, 'hidden' => true, 'env_var' => 'GOOGLE_SEARCH_API_KEY' },
            'search_engine_id' => { 'type' => 'string', 'required' => true, 'hidden' => true, 'env_var' => 'GOOGLE_SEARCH_ENGINE_ID' },
            'num_results'      => { 'type' => 'integer', 'default' => 3, 'min' => 1, 'max' => 10 },
            'no_results_message' => { 'type' => 'string' },
            'response_prefix'  => { 'type' => 'string', 'default' => '' },
            'response_postfix' => { 'type' => 'string', 'default' => '' }
          }
        end

        private

        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          if query.empty?
            return Swaig::FunctionResult.new('Please provide a search query. What would you like me to search for?')
          end

          begin
            results = google_search(query, @num_results)
            if results.empty?
              return Swaig::FunctionResult.new(@no_results_msg)
            end

            formatted = results.map.with_index(1) do |r, i|
              "=== RESULT #{i} ===\nTitle: #{r['title']}\nURL: #{r['url']}\nSnippet: #{r['snippet']}\n#{'=' * 50}"
            end.join("\n\n")

            response = "Web search results for '#{query}':\n\n#{formatted}"
            response = "#{@response_prefix}\n\n#{response}"  unless @response_prefix.nil?  || @response_prefix.empty?
            response = "#{response}\n\n#{@response_postfix}" unless @response_postfix.nil? || @response_postfix.empty?
            Swaig::FunctionResult.new(response)
          rescue => e
            Swaig::FunctionResult.new("Sorry, I encountered an error while searching: #{e.message}")
          end
        end

        def google_search(query, num)
          # Default to Google CSE; WEB_SEARCH_BASE_URL overrides for tests
          # and the audit fixture (matches Rust SDK's behavior — env var is
          # the *host*, the `/customsearch/v1` path is appended below so
          # the audit can match on `customsearch` in req.path).
          base = ENV['WEB_SEARCH_BASE_URL']
          base = 'https://www.googleapis.com' if base.nil? || base.empty?
          uri = URI("#{base.sub(/\/$/, '')}/customsearch/v1")
          uri.query = URI.encode_www_form(
            key: @api_key,
            cx: @search_engine_id,
            q: query,
            num: [num, 10].min
          )

          response = Net::HTTP.get_response(uri)
          return [] unless response.is_a?(Net::HTTPSuccess)

          data = JSON.parse(response.body)
          (data['items'] || []).first(num).map do |item|
            { 'title' => item['title'] || '', 'url' => item['link'] || '', 'snippet' => item['snippet'] || '' }
          end
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('web_search') do |params|
  SignalWire::Skills::Builtin::WebSearchSkill.new(params)
end
