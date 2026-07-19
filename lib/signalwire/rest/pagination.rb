# frozen_string_literal: true

module SignalWire
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

      def initialize(http, path, params = nil, data_key = 'data')
        @http     = http
        @path     = path
        # Dup so callers can't mutate iterator state via the original Hash.
        @params   = params ? params.dup : {}
        @data_key = data_key
        @items    = []
        @index    = 0
        @done     = false
      end

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

      def fetch_next
        params_for_request = @params.empty? ? nil : @params
        resp = @http.get(@path, params_for_request)
        data = resp[@data_key] || []
        @items.concat(data)

        # Termination is driven ONLY by the absence of a next link, NOT by an
        # empty +data+ array on this page. A page can legitimately carry a
        # +links.next+ (more pages exist) while returning zero items on THIS
        # page — e.g. a filtered page that matches nothing here. The old
        # +next_url && !data.empty?+ condition stopped on such a page and
        # silently dropped every subsequent page. Mirrors the Python reference
        # fix (_pagination.py, #58). (A cycle guard against a self-repeating
        # +next+ URL is pending in the Python reference; mirror it here once it
        # lands there.)
        next_url = (resp['links'] || {})['next']
        if next_url
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
