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

        links = resp['links'] || {}
        next_url = links['next']
        if next_url && !data.empty?
          uri = URI.parse(next_url)
          query = URI.decode_www_form(uri.query || '')
          # Flatten single-value lists, preserving multi-value entries.
          flat = {}
          query.each do |k, v|
            if flat.key?(k)
              existing = flat[k]
              flat[k] = existing.is_a?(Array) ? existing + [v] : [existing, v]
            else
              flat[k] = v
            end
          end
          @params = flat
        else
          @done = true
        end
      end
    end
  end
end
