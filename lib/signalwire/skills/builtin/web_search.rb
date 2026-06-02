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
          @min_quality_score = (get_param('min_quality_score', default: 0.3)).to_f
          @default_delay     = (get_param('delay', default: 0.0)).to_f
          @no_results_msg    = get_param('no_results_message',
            default: "I couldn't find quality results for that query. Try rephrasing your search.")

          # Optional prefix/postfix wrapped around every non-empty search
          # result. Use these to give the calling agent a mechanical cue
          # (e.g. "tell the user this came from a public web search")
          # without needing prompt-side rules. Mirrors Python parity.
          @response_prefix   = get_param('response_prefix',  default: '')
          @response_postfix  = get_param('response_postfix', default: '')

          # Latency-control parameters. The SignalWire kernel times out webhook
          # responses around 55s, so the handler MUST finish under that.
          # Mirrors Python's web_search/skill.py (51101da + 295745b).
          #   per_page_timeout: max seconds to wait on a single page scrape
          #     (Net::HTTP open_timeout/read_timeout).
          #   overall_deadline: wall-clock budget for the whole tool call. Once
          #     exceeded, any in-flight scrapes are abandoned and we format
          #     whatever results we already have (or fall back to snippets).
          #   parallel_scrape: fetch all candidate pages concurrently in their
          #     own threads instead of one-after-the-other. Ruby releases the
          #     GIL on blocking I/O, so this helps for network-bound scraping.
          #     Best-effort, NOT contracted.
          #   snippets_only: skip scraping entirely and return Google CSE
          #     snippets only. Fastest mode (sub-second).
          @per_page_timeout  = (get_param('per_page_timeout', default: 2.0)).to_f
          @overall_deadline  = (get_param('overall_deadline', default: 10.0)).to_f
          # get_param uses `||`, so a literal `false` would fall through to the
          # default; read the raw param and coerce booleans ourselves.
          @parallel_scrape   = bool_param('parallel_scrape', true)
          @snippets_only     = bool_param('snippets_only', false)

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
            'response_postfix' => { 'type' => 'string', 'default' => '' },
            # Latency-control params (Python parity: 51101da + 295745b). The
            # SignalWire kernel times out webhook responses around 55s; these
            # bound per-page and whole-call latency and offer a sub-second
            # snippets-only mode.
            'per_page_timeout' => { 'type' => 'number',  'description' => 'Maximum seconds to wait on a single page scrape.', 'default' => 2.0, 'required' => false, 'min' => 0.1 },
            'overall_deadline' => { 'type' => 'number',  'description' => 'Wall-clock budget in seconds for the whole tool call. In-flight scrapes are abandoned past this so the response beats the kernel webhook timeout.', 'default' => 10.0, 'required' => false, 'min' => 1.0 },
            'parallel_scrape'  => { 'type' => 'boolean', 'description' => 'Scrape all candidate pages concurrently (one thread each) instead of sequentially.', 'default' => true, 'required' => false },
            'snippets_only'    => { 'type' => 'boolean', 'description' => 'Skip page scraping entirely and return Google CSE snippets only. Fastest mode (sub-second).', 'default' => false, 'required' => false }
          }
        end

        private

        # Coerce a param to a boolean, treating an absent param as +default+.
        # get_param's `||` chain can't be used for booleans because a literal
        # +false+ would fall through to the default.
        def bool_param(key, default)
          raw = @params[key.to_s]
          return default if raw.nil?
          case raw
          when true, false then raw
          when String      then !%w[false 0 no off].include?(raw.strip.downcase)
          when Numeric     then raw != 0
          else !!raw
          end
        end

        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          if query.empty?
            return Swaig::FunctionResult.new('Please provide a search query. What would you like me to search for?')
          end

          begin
            # overall_deadline is the wall-clock budget for the whole tool call.
            # The SignalWire kernel times out webhook responses around 55s; once
            # this fires, in-flight scrapes are abandoned and we return whatever
            # we have (or fall back to CSE snippets). THIS IS THE CONTRACT.
            deadline_at = monotonic_now + @overall_deadline

            results = google_search(query, @num_results)
            if results.empty?
              return Swaig::FunctionResult.new(@no_results_msg)
            end

            # snippets_only fast path: skip page scraping entirely and format the
            # CSE snippets directly. Sub-second response.
            if @snippets_only
              return Swaig::FunctionResult.new(format_snippet_results(query, results, @num_results))
            end

            # Scrape and score the candidates under the overall_deadline budget.
            # In parallel mode each candidate is fetched in its own thread and
            # joined with the remaining deadline; whatever has not returned by
            # the deadline is abandoned. In sequential mode we scrape one at a
            # time, breaking once the deadline passes. Enforced in BOTH modes.
            processed = scrape_candidates(query, results, deadline_at)

            if processed.empty?
              # Time ran out or every page was below the quality threshold. Fall
              # back to snippet-only results so we return SOMETHING useful before
              # the kernel webhook timeout fires, rather than an empty no-results
              # message. (Python parity: 51101da.)
              return Swaig::FunctionResult.new(format_snippet_results(query, results, @num_results))
            end

            # Sort by quality score descending and keep the best num_results.
            processed.sort_by! { |p| -p['quality_score'] }
            top = processed.first(@num_results)

            formatted = top.map.with_index(1) do |r, i|
              "=== RESULT #{i} ===\nTitle: #{r['title']}\nURL: #{r['url']}\nSnippet: #{r['snippet']}\nContent: #{r['content']}\n#{'=' * 50}"
            end.join("\n\n")

            response = "Quality web search results for '#{query}':\n\n#{formatted}"
            Swaig::FunctionResult.new(wrap_response(response))
          rescue => e
            Swaig::FunctionResult.new("Sorry, I encountered an error while searching: #{e.message}")
          end
        end

        # Scrape + score the candidate results under the overall_deadline budget.
        # Returns the list of enriched result hashes that finished in time and
        # met the quality threshold. The overall_deadline is enforced in both
        # parallel and sequential modes.
        def scrape_candidates(query, results, deadline_at)
          unless @parallel_scrape
            # Sequential mode (legacy). Still honors overall_deadline.
            processed = []
            results.each do |r|
              break if monotonic_now >= deadline_at
              item = scrape_one(query, r, deadline_at)
              processed << item if item
              sleep(@default_delay) if @default_delay > 0
            end
            return processed
          end

          # Parallel mode: dispatch all scrapes at once, then join each thread
          # with the time remaining until the deadline. Ruby threads release the
          # GIL on blocking I/O, so the fetches genuinely overlap. Whatever has
          # not produced a value by the deadline is abandoned (the thread is
          # left to die when the process moves on / its per_page_timeout fires).
          threads = results.map do |r|
            Thread.new { scrape_one(query, r, deadline_at) }
          end

          processed = []
          threads.each do |t|
            remaining = deadline_at - monotonic_now
            if remaining <= 0
              # Out of time. THIS IS THE overall_deadline CONTRACT: stop
              # harvesting and return what we already have. Stragglers are
              # abandoned (each is still capped by per_page_timeout anyway).
              break
            end
            # join returns the thread if it finished within `remaining`, else
            # nil — in which case we abandon it without blocking further.
            item = t.join(remaining) ? t.value : nil
            processed << item if item
          end
          processed
        end

        # Fetch + score one candidate. Returns an enriched hash or nil (empty
        # page / below the quality threshold / past the deadline). Mirrors
        # Python's _scrape_one closure.
        def scrape_one(query, result, deadline_at)
          return nil if monotonic_now >= deadline_at
          text = extract_text_from_url(result['url'])
          return nil if text.nil? || text.empty?
          metrics = calculate_content_quality(text, result['url'], query)
          return nil if metrics['quality_score'] < @min_quality_score
          {
            'title'         => result['title'],
            'url'           => result['url'],
            'snippet'       => result['snippet'],
            'content'       => text,
            'quality_score' => metrics['quality_score'],
            'domain'        => metrics['domain']
          }
        rescue => _e
          nil
        end

        # Fetch a page and extract meaningful text, bounded by per_page_timeout
        # (Net::HTTP open_timeout/read_timeout). Returns the text, or nil on any
        # failure. Mirrors Python's GoogleSearchScraper.extract_text_from_url.
        def extract_text_from_url(url)
          uri = URI(url)
          return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          # per_page_timeout caps both the connect and the read so a single slow
          # page can't blow the overall_deadline on its own.
          http.open_timeout = @per_page_timeout
          http.read_timeout = @per_page_timeout

          req = Net::HTTP::Get.new(uri)
          req['User-Agent'] = 'SignalWire-WebSearch/2.0'

          resp = http.request(req)
          return nil unless resp.is_a?(Net::HTTPSuccess)

          body = resp.body.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
          # Strip scripts/styles/tags and collapse whitespace.
          body.gsub(/<script[^>]*>.*?<\/script>/mi, '')
              .gsub(/<style[^>]*>.*?<\/style>/mi, '')
              .gsub(/<[^>]+>/, ' ')
              .gsub(/\s+/, ' ')
              .strip
        rescue => _e
          nil
        end

        # Lightweight content-quality heuristic. Mirrors the spirit of Python's
        # _calculate_content_quality: longer, query-relevant text scores higher.
        # Returns a hash with at least 'quality_score' and 'domain'.
        def calculate_content_quality(text, url, query)
          domain = begin
            URI(url).host.to_s.downcase
          rescue StandardError
            ''
          end
          length = text.length
          # Length component: saturates around ~2000 chars.
          length_score = [length / 2000.0, 1.0].min
          # Query-relevance component: fraction of query words present.
          words = query.downcase.split(/\W+/).reject(&:empty?).uniq
          relevance = if words.empty?
                        0.0
                      else
                        lower = text.downcase
                        found = words.count { |w| lower.include?(w) }
                        found.to_f / words.length
                      end
          score = (0.5 * length_score) + (0.5 * relevance)
          { 'quality_score' => score, 'domain' => domain, 'text_length' => length, 'query_relevance' => relevance }
        end

        # Format Google CSE snippets without fetching the underlying pages. Used
        # when snippets_only is true, or as a graceful fallback when page
        # scraping is abandoned by the overall_deadline. Always non-empty when
        # CSE returned anything at all, so the kernel never sees a webhook
        # timeout. Mirrors Python's _format_snippet_results.
        def format_snippet_results(query, results, num_results)
          return @no_results_msg if results.empty?

          top = results.first([num_results, 1].max)
          lines = ["Snippet-only results for '#{query}' (page content not scraped):\n"]
          top.each_with_index do |r, i|
            lines << "=== RESULT #{i + 1} ==="
            lines << "Title: #{r['title']}"
            lines << "URL: #{r['url']}"
            lines << "Snippet: #{(r['snippet'] || '').strip}"
            lines << ''
          end
          wrap_response(lines.join("\n").rstrip)
        end

        # Apply the optional response_prefix / response_postfix around a
        # non-empty result body. Shared by the scraped-result and snippet-
        # fallback paths; the error and no-results branches stay unwrapped.
        def wrap_response(response)
          response = "#{@response_prefix}\n\n#{response}"  unless @response_prefix.nil?  || @response_prefix.empty?
          response = "#{response}\n\n#{@response_postfix}" unless @response_postfix.nil? || @response_postfix.empty?
          response
        end

        # Monotonic clock for deadline math — immune to wall-clock adjustments.
        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
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
