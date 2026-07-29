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
      # Private mixin: {WebSearchSkill}'s search orchestration + scrape loop.
      # Extracted purely to keep the skill class within the size budget; every
      # method is private and reads the skill's ivars. Pairs with
      # {WebPageFetcher} (page fetch + quality scoring + CSE call).
      module WebScraping
        private

        # Execute the search and return the formatted response text. Honors the
        # overall_deadline wall-clock budget: the SignalWire kernel times out
        # webhook responses around 55s; once it fires, in-flight scrapes are
        # abandoned and we fall back to CSE snippets. THIS IS THE CONTRACT.
        def run_search(query)
          deadline_at = monotonic_now + overall_deadline
          results = google_search(query, num_results)
          return no_results_msg if results.empty?

          # snippets_only fast path: skip page scraping entirely. Sub-second.
          return format_snippet_results(query, results, num_results) if snippets_only

          processed = scrape_candidates(query, results, deadline_at)
          # Time ran out or every page was below quality threshold: fall back to
          # snippet-only results so we return SOMETHING useful (Python parity).
          return format_snippet_results(query, results, num_results) if processed.empty?

          wrap_response(format_scraped_results(query, processed))
        end

        # Sort by quality score descending, keep the best num_results, render.
        def format_scraped_results(query, processed)
          processed.sort_by! { |p| -p['quality_score'] }
          formatted = processed.first(num_results).map.with_index(1) do |r, i|
            "=== RESULT #{i} ===\nTitle: #{r['title']}\nURL: #{r['url']}\n" \
              "Snippet: #{r['snippet']}\nContent: #{r['content']}\n#{'=' * 50}"
          end.join("\n\n")
          "Quality web search results for '#{query}':\n\n#{formatted}"
        end

        # Scrape + score the candidate results under the overall_deadline budget.
        # Returns the list of enriched result hashes that finished in time and
        # met the quality threshold. The overall_deadline is enforced in both
        # parallel and sequential modes.
        def scrape_candidates(query, results, deadline_at)
          if parallel_scrape
            scrape_parallel(query, results, deadline_at)
          else
            scrape_sequential(query, results, deadline_at)
          end
        end

        # Sequential mode (legacy). Still honors overall_deadline.
        def scrape_sequential(query, results, deadline_at)
          processed = []
          results.each do |r|
            break if monotonic_now >= deadline_at

            item = scrape_one(query, r, deadline_at)
            processed << item if item
            sleep(default_delay) if default_delay.positive?
          end
          processed
        end

        # Parallel mode: dispatch all scrapes at once, then join each thread
        # with the time remaining until the deadline. Ruby threads release the
        # GIL on blocking I/O, so the fetches genuinely overlap. Whatever has
        # not produced a value by the deadline is abandoned (the thread is
        # left to die when the process moves on / its per_page_timeout fires).
        def scrape_parallel(query, results, deadline_at)
          threads = results.map { |r| Thread.new { scrape_one(query, r, deadline_at) } }

          processed = []
          threads.each do |t|
            remaining = deadline_at - monotonic_now
            # Out of time. THIS IS THE overall_deadline CONTRACT: stop
            # harvesting and return what we already have. Stragglers are
            # abandoned (each is still capped by per_page_timeout anyway).
            break if remaining <= 0

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
          return nil if metrics['quality_score'] < min_quality_score

          { 'title' => result['title'], 'url' => result['url'], 'snippet' => result['snippet'],
            'content' => text, 'quality_score' => metrics['quality_score'],
            'domain' => metrics['domain'] }
        rescue StandardError => _e
          nil
        end
      end

      # Private mixin: {WebSearchSkill}'s page fetch, HTML strip, content-quality
      # scoring, snippet formatting, and Google CSE call. Pairs with
      # {WebScraping}; both are included into the skill and share its ivars.
      module WebPageFetcher
        private

        # Fetch a page and extract meaningful text, bounded by per_page_timeout
        # (Net::HTTP open_timeout/read_timeout). Returns the text, or nil on any
        # failure. Mirrors Python's GoogleSearchScraper.extract_text_from_url.
        def extract_text_from_url(url)
          uri = URI(url)
          return nil unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

          resp = fetch_page(uri)
          return nil unless resp.is_a?(Net::HTTPSuccess)

          body = resp.body.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
          strip_html(body)
        rescue StandardError => _e
          nil
        end

        # GET +uri+ with per_page_timeout capping both connect and read so a
        # single slow page can't blow the overall_deadline on its own.
        def fetch_page(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = (uri.scheme == 'https')
          http.open_timeout = per_page_timeout
          http.read_timeout = per_page_timeout

          req = Net::HTTP::Get.new(uri)
          req['User-Agent'] = 'SignalWire-WebSearch/2.0'
          http.request(req)
        end

        # Strip scripts/styles/tags and collapse whitespace.
        def strip_html(body)
          body.gsub(%r{<script[^>]*>.*?</script>}mi, '')
              .gsub(%r{<style[^>]*>.*?</style>}mi, '')
              .gsub(/<[^>]+>/, ' ')
              .gsub(/\s+/, ' ')
              .strip
        end

        # Lightweight content-quality heuristic. Mirrors the spirit of Python's
        # _calculate_content_quality: longer, query-relevant text scores higher.
        # Returns a hash with at least 'quality_score' and 'domain'.
        def calculate_content_quality(text, url, query)
          length = text.length
          # Length component: saturates around ~2000 chars.
          length_score = [length / 2000.0, 1.0].min
          relevance = query_relevance(text, query)
          score = (0.5 * length_score) + (0.5 * relevance)
          { 'quality_score' => score, 'domain' => url_domain(url),
            'text_length' => length, 'query_relevance' => relevance }
        end

        def url_domain(url)
          URI(url).host.to_s.downcase
        rescue StandardError
          ''
        end

        # Fraction of distinct query words present in the text (0.0 if none).
        def query_relevance(text, query)
          words = query.downcase.split(/\W+/).reject(&:empty?).uniq
          return 0.0 if words.empty?

          lower = text.downcase
          words.count { |w| lower.include?(w) }.to_f / words.length
        end

        # Format Google CSE snippets without fetching the underlying pages. Used
        # when snippets_only is true, or as a graceful fallback when page
        # scraping is abandoned by the overall_deadline. Always non-empty when
        # CSE returned anything at all, so the kernel never sees a webhook
        # timeout. Mirrors Python's _format_snippet_results.
        def format_snippet_results(query, results, num_results)
          return no_results_msg if results.empty?

          top = results.first([num_results, 1].max)
          lines = ["Snippet-only results for '#{query}' (page content not scraped):\n"]
          top.each_with_index { |r, i| lines.concat(snippet_result_lines(r, i)) }
          wrap_response(lines.join("\n").rstrip)
        end

        def snippet_result_lines(result, index)
          ["=== RESULT #{index + 1} ===",
           "Title: #{result['title']}",
           "URL: #{result['url']}",
           "Snippet: #{(result['snippet'] || '').strip}",
           '']
        end

        # Apply the optional response_prefix / response_postfix around a
        # non-empty result body. Shared by the scraped-result and snippet-
        # fallback paths; the error and no-results branches stay unwrapped.
        def wrap_response(response)
          response = "#{response_prefix}\n\n#{response}"  unless response_prefix.nil?  || response_prefix.empty?
          response = "#{response}\n\n#{response_postfix}" unless response_postfix.nil? || response_postfix.empty?
          response
        end

        # Monotonic clock for deadline math — immune to wall-clock adjustments.
        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def google_search(query, num)
          uri = google_search_uri(query, num)
          response = Net::HTTP.get_response(uri)
          return [] unless response.is_a?(Net::HTTPSuccess)

          data = JSON.parse(response.body)
          (data['items'] || []).first(num).map do |item|
            { 'title' => item['title'] || '', 'url' => item['link'] || '', 'snippet' => item['snippet'] || '' }
          end
        end

        # Build the Google CSE request URI. WEB_SEARCH_BASE_URL overrides the
        # host for tests and the audit fixture (matches the Rust SDK — env var
        # is the *host*, the `/customsearch/v1` path is appended so the audit
        # can match on `customsearch` in req.path).
        def google_search_uri(query, num)
          base = resolved_base_url('WEB_SEARCH_BASE_URL', 'https://www.googleapis.com')
          uri = URI("#{base}/customsearch/v1")
          uri.query = URI.encode_www_form(
            key: api_key, cx: search_engine_id, q: query, num: [num, 10].min
          )
          uri
        end
      end

      # Private mixin: {WebSearchSkill}'s param parsing + SWAIG parameter-schema
      # builders + prompt-section bullets. The description constants are
      # wire-load-bearing (match the Python reference). Extracted to keep the
      # skill class within the size budget.
      module WebSearchConfig
        DEFAULT_NO_RESULTS_MESSAGE =
          "I couldn't find quality results for that query. Try rephrasing your search."

        # SWAIG parameter-schema descriptions (wire-load-bearing — match Python).
        PER_PAGE_TIMEOUT_DESC = 'Maximum seconds to wait on a single page scrape.'
        OVERALL_DEADLINE_DESC =
          'Wall-clock budget in seconds for the whole tool call. In-flight scrapes are ' \
          'abandoned past this so the response beats the kernel webhook timeout.'
        PARALLEL_SCRAPE_DESC =
          'Scrape all candidate pages concurrently (one thread each) instead of sequentially.'
        SNIPPETS_ONLY_DESC =
          'Skip page scraping entirely and return Google CSE snippets only. ' \
          'Fastest mode (sub-second).'

        private

        # Config ivars populated by #read_core_params / #read_latency_params.
        attr_reader :api_key, :search_engine_id, :num_results, :tool_name,
                    :min_quality_score, :default_delay, :no_results_msg,
                    :response_prefix, :response_postfix, :per_page_timeout,
                    :overall_deadline, :parallel_scrape, :snippets_only

        def prompt_section_bullets
          [
            "Use the #{tool_name} tool when users ask for information you need to look up",
            'The search automatically filters out low-quality results like empty pages',
            'Results are ranked by content quality, relevance, and domain reputation',
            'Summarize the high-quality results in a clear, helpful way'
          ]
        end

        def core_parameter_schema
          {
            'api_key' => { 'type' => 'string', 'required' => true, 'hidden' => true,
                           'env_var' => 'GOOGLE_SEARCH_API_KEY' },
            'search_engine_id' => { 'type' => 'string', 'required' => true, 'hidden' => true,
                                    'env_var' => 'GOOGLE_SEARCH_ENGINE_ID' },
            'num_results' => { 'type' => 'integer', 'default' => 3, 'min' => 1, 'max' => 10 },
            'no_results_message' => { 'type' => 'string' },
            'response_prefix' => { 'type' => 'string', 'default' => '' },
            'response_postfix' => { 'type' => 'string', 'default' => '' }
          }
        end

        # Latency-control params. The
        # SignalWire kernel times out webhook responses around 55s; these
        # bound per-page and whole-call latency and offer a sub-second
        # snippets-only mode.
        def latency_parameter_schema
          {
            'per_page_timeout' => { 'type' => 'number', 'description' => PER_PAGE_TIMEOUT_DESC,
                                    'default' => 2.0, 'required' => false, 'min' => 0.1 },
            'overall_deadline' => { 'type' => 'number', 'description' => OVERALL_DEADLINE_DESC,
                                    'default' => 10.0, 'required' => false, 'min' => 1.0 },
            'parallel_scrape' => { 'type' => 'boolean', 'description' => PARALLEL_SCRAPE_DESC,
                                   'default' => true, 'required' => false },
            'snippets_only' => { 'type' => 'boolean', 'description' => SNIPPETS_ONLY_DESC,
                                 'default' => false, 'required' => false }
          }
        end

        def read_core_params
          @api_key           = get_param('api_key', env_var: 'GOOGLE_SEARCH_API_KEY')
          @search_engine_id  = get_param('search_engine_id', env_var: 'GOOGLE_SEARCH_ENGINE_ID')
          @num_results       = get_param('num_results', default: 3).to_i
          @tool_name         = get_param('tool_name', default: 'web_search')
          @min_quality_score = get_param('min_quality_score', default: 0.3).to_f
          @default_delay     = get_param('delay', default: 0.0).to_f
          @no_results_msg    = get_param('no_results_message', default: DEFAULT_NO_RESULTS_MESSAGE)
          # Optional prefix/postfix wrapped around every non-empty search
          # result. Use these to give the calling agent a mechanical cue
          # (e.g. "tell the user this came from a public web search")
          # without needing prompt-side rules. Mirrors Python parity.
          @response_prefix   = get_param('response_prefix',  default: '')
          @response_postfix  = get_param('response_postfix', default: '')
        end

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
        def read_latency_params
          @per_page_timeout  = get_param('per_page_timeout', default: 2.0).to_f
          @overall_deadline  = get_param('overall_deadline', default: 10.0).to_f
          # get_param uses `||`, so a literal `false` would fall through to the
          # default; read the raw param and coerce booleans ourselves.
          @parallel_scrape   = bool_param('parallel_scrape', true)
          @snippets_only     = bool_param('snippets_only', false)
        end

        # Coerce a param to a boolean, treating an absent param as +default+.
        # get_param's `||` chain can't be used for booleans because a literal
        # +false+ would fall through to the default.
        def bool_param(key, default)
          raw = params[key.to_s]
          return default if raw.nil?

          case raw
          when true, false then raw
          when String      then !%w[false 0 no off].include?(raw.strip.downcase)
          when Numeric     then raw != 0
          else !!raw
          end
        end
      end

      class WebSearchSkill < SkillBase
        include WebScraping
        include WebPageFetcher
        include WebSearchConfig

        TOOL_DESCRIPTION =
          'Search the web for high-quality information, automatically filtering low-quality results'
        QUERY_PARAM_DESC = 'The search query - what you want to find information about'

        def name = 'web_search'
        def description = 'Search the web for information using Google Custom Search API'
        # This skill's own version, independent of the SDK's.
        #
        # @return [String] '2.0.0'
        def version = '2.0.0'
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
          read_core_params
          read_latency_params

          return false unless api_key && !api_key.empty?
          return false unless search_engine_id && !search_engine_id.empty?

          true
        end

        def instance_key = "web_search_#{tool_name}"

        # The SWAIG tool definitions this skill contributes to its agent. Each
        # entry is a `{name:, description:, parameters:, handler:}` hash; the
        # descriptions are what the model reads to decide when and how to call
        # the tool.
        #
        # @return [Array<Hash>]
        def register_tools
          [
            {
              name: tool_name,
              description: TOOL_DESCRIPTION,
              parameters: { 'query' => { 'type' => 'string', 'description' => QUERY_PARAM_DESC } },
              handler: method(:handle_search)
            }
          ]
        end

        # Returns [] — this skill ships no example hints.
        def get_hints = []

        # Data this skill merges into the agent's `global_data`, so its prompts
        # and tools can reference the values as `${global_data.*}`.
        #
        # @return [Hash]
        def get_global_data
          { 'web_search_enabled' => true, 'search_provider' => 'Google Custom Search', 'quality_filtering' => true }
        end

        # The POM sections this skill contributes to the agent's prompt,
        # teaching the model when to reach for the skill's tools. Returned as
        # fresh copies, so a caller mutating them does not corrupt skill state.
        #
        # @return [Array<Hash>]
        def get_prompt_sections
          [
            {
              'title' => 'Web Search Capability (Quality Enhanced)',
              'body' => "You can search the internet for high-quality information using the #{tool_name} tool.",
              'bullets' => prompt_section_bullets
            }
          ]
        end

        # The JSON-Schema description of this skill's configuration params, for
        # GUI and validation consumers.
        #
        # @return [Hash]
        def get_parameter_schema
          core_parameter_schema.merge(latency_parameter_schema)
        end

        private

        def handle_search(args, _raw_data)
          query = (args['query'] || '').strip
          if query.empty?
            return Swaig::FunctionResult.new('Please provide a search query. What would you like me to search for?')
          end

          Swaig::FunctionResult.new(run_search(query))
        rescue StandardError => e
          Swaig::FunctionResult.new("Sorry, I encountered an error while searching: #{e.message}")
        end
      end
    end
  end
end

SignalWire::Skills::SkillRegistry.register('web_search') do |params|
  SignalWire::Skills::Builtin::WebSearchSkill.new(params)
end
