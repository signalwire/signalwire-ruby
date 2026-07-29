# frozen_string_literal: true

module SignalWire
  # REST — the synchronous REST client and its per-namespace resources.
  module REST
    # Iterates items across paginated API responses.
    #
    # Mirrors the Python PaginatedIterator (signalwire.rest._pagination):
    # the constructor records http/path/params/data_key without fetching;
    # iteration walks pages by following the +links.next+ cursor.
    #
    # Usage:
    #   iter = SignalWire::REST::PaginatedIterator.new(http, '/api/path',
    #                                                  params: {}, data_key: 'data')
    #   iter.each { |item| ... }
    #
    # The iterator is single-pass (matching Python's __next__ semantics);
    # use #to_a to collect every item across all pages.
    class PaginatedIterator
      include Enumerable

      attr_reader :http, :path, :params, :data_key, :index, :items, :done

      # @param http [HttpClient] the transport each page fetch goes through
      # @param path [String] the collection path to page over
      # @param params [Hash, nil] initial query parameters; duplicated so a caller
      #   mutating the original cannot corrupt iterator state
      # @param data_key [String] the response key holding the page's items
      # @param request_options [RequestOptions, nil] forwarded to EVERY page fetch, so
      #   pagination honours the same timeout/retry contract as a single call
      def initialize(http, path, params = nil, data_key = 'data', request_options = nil)
        @http     = http
        @path     = path
        # Dup so callers can't mutate iterator state via the original Hash.
        @params   = params ? params.dup : {}
        @data_key = data_key
        # Per-request options (timeout / connect_timeout / headers) forwarded to
        # every page fetch, so pagination honors the same request contract as a
        # single call. Mirrors Python _pagination.py's +request_options+ thread.
        @request_options = request_options
        @items    = []
        @index    = 0
        @done     = false
        # Cycle guard: +links.next+ cursors already followed. A server that keeps
        # returning the SAME +next+ would otherwise loop forever (the empty-page
        # fix terminates only on an ABSENT next link, so a repeating next became
        # an infinite loop). Seeing a repeat terminates iteration. Mirrors the
        # python reference (_pagination.py _seen_next).
        @seen_next = {}
      end

      # Yield every item across all pages, fetching pages as needed. Without a block
      # returns an Enumerator, so the whole Enumerable surface (`map`, `take`, …)
      # works lazily over the pages.
      #
      # @return [Enumerator, void]
      def each
        return enum_for(:each) unless block_given?

        loop do
          item = next_item
          break if item == :__stop__

          yield item
        end
      end

      # Python iterator-protocol parity. Python's PaginatedIterator exposes
      # +__iter__+ (returns self) and +__next__+ (advances one item, raising
      # +StopIteration+ when exhausted). Ruby's idiomatic surface is +#each+ /
      # +#next_item+, but we expose these thin aliases so the protocol shape
      # matches the Python reference one-to-one.

      # Equivalent of Python's +__iter__+: returns the iterator itself.
      def __iter__
        self
      end

      # Equivalent of Python's +__next__+: returns the next item across pages,
      # raising +StopIteration+ when the iterator is exhausted (mirroring
      # Python's raise-StopIteration contract rather than the +:__stop__+
      # sentinel used internally by +#each+).
      def __next__
        item = next_item
        raise StopIteration if item == :__stop__

        item
      end

      # Equivalent of Python's __next__. Returns the sentinel +:__stop__+
      # when exhausted (Ruby has no StopIteration error idiom for plain
      # Enumerable), but the public surface is +#each+.
      def next_item
        while @index >= @items.length
          return :__stop__ if @done

          fetch_next
        end
        item = @items[@index]
        @index += 1
        item
      end

      private

      # @api private — fetch one page, append its items, and decide whether to
      # continue. Termination is driven ONLY by the absence of a `links.next` — an
      # empty `data` array does NOT stop iteration, because a filtered page can
      # legitimately match nothing while later pages still have items.
      def fetch_next
        params_for_request = @params.empty? ? nil : @params
        resp = @http.get(@path, params_for_request, request_options: @request_options)
        data = resp[@data_key] || []
        @items.concat(data)

        # Termination is driven ONLY by the absence of a next link, NOT by an
        # empty +data+ array on this page. A page can legitimately carry a
        # +links.next+ (more pages exist) while returning zero items on THIS
        # page — e.g. a filtered page that matches nothing here. The old
        # +next_url && !data.empty?+ condition stopped on such a page and
        # silently dropped every subsequent page. Mirrors the Python reference
        # fix (_pagination.py, #58).
        advance_or_finish((resp['links'] || {})['next'])
      end

      # Advance to the next page, or terminate. A +next+ we have already followed
      # (repeating cursor) or an absent +next+ both terminate — the cycle guard
      # prevents an infinite re-fetch loop. Mirrors python _pagination.py _seen_next.
      def advance_or_finish(next_url)
        if next_url && !@seen_next.key?(next_url)
          @seen_next[next_url] = true
          @params = params_from_next_url(next_url)
        else
          @done = true
        end
      end

      # Parse the +next+ link's query string into a params hash, flattening
      # single-value entries while preserving multi-value ones.
      def params_from_next_url(next_url)
        query = URI.decode_www_form(URI.parse(next_url).query || '')
        query.each_with_object({}) { |(k, v), flat| merge_query_param(flat, k, v) }
      end

      # @api private — fold one query pair into the params Hash, promoting a repeated
      # key to an Array so a multi-value parameter in the `next` link survives being
      # re-sent.
      def merge_query_param(flat, key, value)
        if flat.key?(key)
          existing = flat[key]
          flat[key] = existing.is_a?(Array) ? existing + [value] : [existing, value]
        else
          flat[key] = value
        end
      end
    end
  end
end
