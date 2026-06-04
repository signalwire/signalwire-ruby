# frozen_string_literal: true

require 'net/http'
require 'uri'

require_relative '../skill_base'
require_relative '../skill_registry'

module SignalWire
  module Skills
    module Builtin
      class SpiderSkill < SkillBase
        def name;        'spider'; end
        def description; 'Fast web scraping and crawling capabilities'; end
        def supports_multiple_instances?; true; end

        def setup
          @max_text_length = (get_param('max_text_length', default: 10_000)).to_i
          @timeout         = (get_param('timeout', default: 5)).to_i
          @user_agent      = get_param('user_agent', default: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
          @tool_prefix     = get_param('tool_name', default: '')
          @tool_prefix     = "#{@tool_prefix}_" unless @tool_prefix.empty?
          @cache_enabled   = get_param('cache_enabled', default: true) != false
          # Response cache, mirroring Python's per-instance fetch cache. Held as
          # state so #cleanup has something concrete to tear down.
          @cache = @cache_enabled ? {} : nil
          true
        end

        # Python parity: ``SpiderSkill.cleanup`` closes the HTTP session, clears
        # the response cache, and logs. Ruby opens a fresh Net::HTTP connection
        # per request (no persistent session to close), so teardown here drops
        # the response cache and logs that the skill was cleaned up. Safe to
        # call more than once.
        def cleanup
          @cache&.clear
          @cache = nil
          logger.info('Spider skill cleaned up')
          nil
        end

        def instance_key
          "spider_#{get_param('tool_name', default: 'spider')}"
        end

        def register_tools
          [
            {
              name: "#{@tool_prefix}scrape_url",
              description: 'Extract text content from a single web page',
              parameters: { 'url' => { 'type' => 'string', 'description' => 'The URL to scrape' } },
              handler: method(:handle_scrape)
            },
            {
              name: "#{@tool_prefix}crawl_site",
              description: 'Crawl multiple pages starting from a URL',
              parameters: { 'start_url' => { 'type' => 'string', 'description' => 'Starting URL for the crawl' } },
              handler: method(:handle_crawl)
            },
            {
              name: "#{@tool_prefix}extract_structured_data",
              description: 'Extract specific data from a web page using selectors',
              parameters: { 'url' => { 'type' => 'string', 'description' => 'The URL to scrape' } },
              handler: method(:handle_extract)
            }
          ]
        end

        def get_hints
          %w[scrape crawl extract web\ page website spider]
        end

        def get_parameter_schema
          {
            'timeout'         => { 'type' => 'integer', 'default' => 5 },
            'max_text_length' => { 'type' => 'integer', 'default' => 10_000 },
            'user_agent'      => { 'type' => 'string' }
          }
        end

        private

        def handle_scrape(args, _raw_data)
          url = (args['url'] || '').strip
          return Swaig::FunctionResult.new('Please provide a URL to scrape') if url.empty?

          text = fetch_text(url)
          if text.nil? || text.empty?
            return Swaig::FunctionResult.new("Failed to fetch or no content from #{url}")
          end

          Swaig::FunctionResult.new("Content from #{url} (#{text.length} characters):\n\n#{text}")
        rescue => e
          Swaig::FunctionResult.new("Error scraping #{url}: #{e.message}")
        end

        def handle_crawl(args, _raw_data)
          url = (args['start_url'] || '').strip
          return Swaig::FunctionResult.new('Please provide a starting URL for the crawl') if url.empty?

          text = fetch_text(url)
          if text.nil? || text.empty?
            return Swaig::FunctionResult.new("No pages could be crawled from #{url}")
          end

          summary = text.length > 500 ? text[0, 500] + '...' : text
          Swaig::FunctionResult.new("Crawled 1 page from #{URI(url).host}:\n\n1. #{url} (#{text.length} chars)\n   Summary: #{summary}")
        rescue => e
          Swaig::FunctionResult.new("Error crawling #{url}: #{e.message}")
        end

        def handle_extract(args, _raw_data)
          url = (args['url'] || '').strip
          return Swaig::FunctionResult.new('Please provide a URL') if url.empty?

          text = fetch_text(url)
          if text.nil? || text.empty?
            return Swaig::FunctionResult.new("Failed to fetch #{url}")
          end

          Swaig::FunctionResult.new("Extracted data from #{url}:\n\nContent: #{text[0, 2000]}")
        rescue => e
          Swaig::FunctionResult.new("Error extracting data: #{e.message}")
        end

        def fetch_text(url)
          # SPIDER_BASE_URL redirects every fetch through a configured host
          # (used by audit_skills_dispatch.py to point the skill at a
          # loopback fixture). The path/query of the user-supplied URL is
          # preserved so the audit can match on it.
          base = ENV['SPIDER_BASE_URL']
          if base && !base.empty?
            url = "#{base.sub(/\/$/, '')}#{_url_path(url)}"
          end

          # Serve from cache when enabled (parallels Python's response cache).
          cache = defined?(@cache) ? @cache : nil
          return cache[url] if cache && cache.key?(url)

          uri = URI(url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = @timeout
          http.read_timeout = @timeout

          req = Net::HTTP::Get.new(uri)
          req['User-Agent'] = @user_agent

          resp = http.request(req)
          return nil unless resp.is_a?(Net::HTTPSuccess)

          body = resp.body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
          # Some upstreams (and the audit fixture) wrap the HTML in JSON
          # under an `_raw_html` field; unwrap before stripping tags.
          begin
            parsed = JSON.parse(body)
            if parsed.is_a?(Hash) && parsed['_raw_html'].is_a?(String)
              body = parsed['_raw_html']
            end
          rescue JSON::ParserError
            # not JSON — treat as raw HTML
          end

          # Strip HTML tags
          text = body.gsub(/<script[^>]*>.*?<\/script>/mi, '')
                     .gsub(/<style[^>]*>.*?<\/style>/mi, '')
                     .gsub(/<[^>]+>/, ' ')
                     .gsub(/\s+/, ' ')
                     .strip

          result = text.length > @max_text_length ? text[0, @max_text_length] : text
          cache[url] = result if cache
          result
        rescue => _e
          nil
        end

        # Extract the path-and-query portion of a URL. Used by
        # SPIDER_BASE_URL redirection to preserve audit fixture matching.
        def _url_path(url)
          stripped = url.sub(%r{\Ahttps?://[^/]+}, '')
          stripped.empty? ? '/' : stripped
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('spider') do |params|
  SignalWire::Skills::Builtin::SpiderSkill.new(params)
end
