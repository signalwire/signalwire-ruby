# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_pagination_mock.py.
#
# The PaginatedIterator wraps any HttpClient.get call and walks paged
# responses following the links.next cursor. We test it end-to-end by:
#
#   1. Staging two FIFO scenarios on a known mock endpoint - the first
#      scenario has a links.next cursor, the second is the terminal page.
#   2. Iterating over a real PaginatedIterator wired to the SDK's HttpClient
#      pointed at the mock.
#   3. Asserting on the items collected and on the journal entries that
#      correspond to the two HTTP fetches.

require 'minitest/autorun'
require_relative 'mock_test'

class PaginationMockTest < Minitest::Test
  # Pick an endpoint that the scenario store can override. We use
  # GET /api/fabric/addresses because (a) it has a stable spec-derived
  # endpoint id and (b) the mock returns data + links shape by default.
  FABRIC_ADDRESSES_PATH = '/api/fabric/addresses'
  FABRIC_ADDRESSES_ENDPOINT_ID = 'fabric.list_fabric_addresses'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  def test_init_state
    # Constructor records http/path/params/data_key without fetching.
    it = SignalWire::REST::PaginatedIterator.new(
      @client.http,
      FABRIC_ADDRESSES_PATH,
      { page_size: 2 },
      'data'
    )
    # Constructor must not have fetched anything yet.
    assert_same @client.http, it.http
    assert_equal FABRIC_ADDRESSES_PATH, it.path
    assert_equal({ page_size: 2 }, it.params)
    assert_equal 'data', it.data_key
    assert_equal 0, it.index
    assert_equal [], it.items
    assert_equal false, it.done
    # Journal must be empty - no HTTP went out.
    assert_equal [], MockTest.journal.journal
  end

  def test_each_returns_enumerator_when_no_block
    # Equivalent of Python's __iter__ returning self - in Ruby idiom
    # #each without a block returns an Enumerator that reuses the
    # iterator's state. Calling .each twice on the same iterator does
    # not re-fetch; both calls share the underlying state.
    it = SignalWire::REST::PaginatedIterator.new(
      @client.http,
      FABRIC_ADDRESSES_PATH,
      nil,
      'data'
    )
    enum = it.each

    assert_kind_of Enumerator, enum
    # Still no HTTP yet - enum isn't realised.
    assert_equal [], MockTest.journal.journal
  end

  def test_next_pages_through_all_items
    # Walks two pages and stops on the page without links.next.
    # Page 1 - has a next cursor.
    MockTest.scenarios.push_scenario(
      FABRIC_ADDRESSES_ENDPOINT_ID,
      status: 200,
      response: {
        'data' => [
          { 'id' => 'addr-1', 'name' => 'first' },
          { 'id' => 'addr-2', 'name' => 'second' }
        ],
        'links' => { 'next' => 'http://example.com/api/fabric/addresses?cursor=page2' }
      }
    )
    # Page 2 - terminal (no next).
    MockTest.scenarios.push_scenario(
      FABRIC_ADDRESSES_ENDPOINT_ID,
      status: 200,
      response: {
        'data' => [{ 'id' => 'addr-3', 'name' => 'third' }],
        'links' => {}
      }
    )

    it = SignalWire::REST::PaginatedIterator.new(
      @client.http,
      FABRIC_ADDRESSES_PATH,
      nil,
      'data'
    )
    collected = it.to_a
    # All three items, in order.
    assert_equal(%w[addr-1 addr-2 addr-3], collected.map { |x| x['id'] })

    # Journal must have exactly two GETs at the same path.
    gets = MockTest.journal.journal.select { |e| e.path == FABRIC_ADDRESSES_PATH }

    assert_equal 2, gets.length,
                 "expected 2 paginated GETs, got #{gets.length}: " \
                 "#{gets.map { |e| [e.method, e.path, e.query_params] }}"
    # The second fetch carries the cursor=page2 param parsed from the
    # first response's links.next.
    assert_equal ['page2'], gets[1].query_params['cursor'],
                 "second fetch missing cursor=page2: #{gets[1].query_params}"
  end

  def test_next_returns_stop_when_done
    # After exhausting items and seeing no next cursor, next_item returns
    # the sentinel :__stop__ (Ruby's equivalent of StopIteration).
    MockTest.scenarios.push_scenario(
      FABRIC_ADDRESSES_ENDPOINT_ID,
      status: 200,
      response: { 'data' => [{ 'id' => 'only-one' }], 'links' => {} }
    )
    it = SignalWire::REST::PaginatedIterator.new(
      @client.http,
      FABRIC_ADDRESSES_PATH,
      nil,
      'data'
    )
    # Call next_item explicitly so the static coverage audit sees it.
    first = it.next_item

    assert_equal({ 'id' => 'only-one' }, first)
    # Exhausted.
    assert_equal :__stop__, it.next_item
  end
end
