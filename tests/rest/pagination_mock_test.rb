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
  # Parallelize: per-client unique-project + auth-scoped harness isolates each test.
  parallelize_me!

  # Pick an endpoint that the scenario store can override. We use
  # GET /api/fabric/addresses because (a) it has a stable spec-derived
  # endpoint id and (b) the mock returns data + links shape by default.
  FABRIC_ADDRESSES_PATH = '/api/fabric/addresses'
  FABRIC_ADDRESSES_ENDPOINT_ID = 'fabric.list_fabric_addresses'

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  def test_init_state
    # Constructor records http/path/params/data_key without fetching.
    iter = build_iterator(page_size: 2)

    assert_init_state(iter)
    # Journal must be empty - no HTTP went out.
    assert_equal [], @mock.journal
  end

  # Constructor must not have fetched anything yet.
  def assert_init_state(iter)
    assert_same @client.http, iter.http
    assert_equal FABRIC_ADDRESSES_PATH, iter.path
    assert_equal({ page_size: 2 }, iter.params)
    assert_equal 'data', iter.data_key
    assert_equal 0, iter.index
    assert_equal [], iter.items
    refute iter.done
  end

  def test_each_returns_enumerator_when_no_block
    # Equivalent of Python's __iter__ returning self - in Ruby idiom
    # #each without a block returns an Enumerator that reuses the
    # iterator's state. Calling .each twice on the same iterator does
    # not re-fetch; both calls share the underlying state.
    iter = build_iterator
    enum = iter.each

    assert_kind_of Enumerator, enum
    # Still no HTTP yet - enum isn't realised.
    assert_equal [], @mock.journal
  end

  def test_next_pages_through_all_items
    # Walks two pages and stops on the page without links.next.
    stage_two_page_scenario

    collected = build_iterator.to_a
    # All three items, in order.
    assert_equal(%w[addr-1 addr-2 addr-3], collected.map { |x| x['id'] })
    assert_two_paginated_gets
  end

  def assert_two_paginated_gets
    # Journal must have exactly two GETs at the same path.
    gets = @mock.journal.select { |e| e.path == FABRIC_ADDRESSES_PATH }
    summary = gets.map { |e| [e.method, e.path, e.query_params] }

    assert_equal 2, gets.length, "expected 2 paginated GETs, got #{gets.length}: #{summary}"
    # The second fetch carries the page_token param parsed from the first
    # response's links.next - the real wire token the server round-trips
    # (a cursor token starting with PA/PB), not a fictional cursor param
    # (no SignalWire REST endpoint accepts cursor - see
    # rest-apis/fabric/openapi.yaml ListFabricAddressesQuery).
    second_params = gets[1].query_params

    assert_equal ['PA_page2'], second_params['page_token'],
                 "second fetch missing page_token=PA_page2: #{second_params}"
  end

  # Stage one page on the addresses endpoint with the given data + links.
  def push_page(data, links)
    @mock.push_scenario(
      FABRIC_ADDRESSES_ENDPOINT_ID,
      status: 200,
      response: { 'data' => data, 'links' => links }
    )
  end

  # Build an iterator over the addresses endpoint (no fetch yet).
  def build_iterator(params = nil)
    SignalWire::REST::PaginatedIterator.new(@client.http, FABRIC_ADDRESSES_PATH, params, 'data')
  end

  # Page 1 has a next cursor; page 2 is terminal (no links.next).
  def stage_two_page_scenario
    page1 = [{ 'id' => 'addr-1', 'name' => 'first' }, { 'id' => 'addr-2', 'name' => 'second' }]
    push_page(page1, { 'next' => 'http://example.com/api/fabric/addresses?page_token=PA_page2' })
    push_page([{ 'id' => 'addr-3', 'name' => 'third' }], {})
  end

  # A page may legitimately carry a links.next (more pages exist) while
  # returning ZERO items on THIS page — e.g. a filtered page that matched
  # nothing here. Termination is driven ONLY by the absence of a next link,
  # never by an empty data array. The old `next_url && !data.empty?` stopped on
  # such a page and silently dropped every subsequent page. Mirrors the Python
  # reference fix (_pagination.py, #58).
  def test_continues_past_empty_page_with_next_link
    # Page 1: empty data but a next cursor. Page 2: the real items, terminal.
    push_page([], { 'next' => 'http://example.com/api/fabric/addresses?page_token=PA_page2' })
    push_page([{ 'id' => 'addr-late', 'name' => 'arrived' }], {})

    collected = build_iterator.to_a

    assert_equal(%w[addr-late], collected.map { |x| x['id'] })
    assert_two_paginated_gets
  end

  def test_next_returns_stop_when_done
    # After exhausting items and seeing no next cursor, next_item returns
    # the sentinel :__stop__ (Ruby's equivalent of StopIteration).
    push_page([{ 'id' => 'only-one' }], {})
    iter = build_iterator
    # Call next_item explicitly so the static coverage audit sees it.
    first = iter.next_item

    assert_equal({ 'id' => 'only-one' }, first)
    # Exhausted.
    assert_equal :__stop__, iter.next_item
  end

  # ReadResource#paginate parity (Python ReadResource.paginate -> PaginatedIterator).
  # The resource-level accessor must build a PaginatedIterator wired to the
  # resource's own collection path, deferring all HTTP until iterated, and walk
  # every page following links.next — so callers page a list endpoint without
  # hand-building the token loop.
  def test_resource_paginate_returns_lazy_iterator
    iter = @client.fabric.addresses.paginate(page_size: 2)

    # It is the real page-walking iterator, wired to this resource's path,
    # and has fetched nothing yet (lazy, like Python's returned iterator).
    assert_kind_of SignalWire::REST::PaginatedIterator, iter
    assert_equal FABRIC_ADDRESSES_PATH, iter.path
    assert_equal({ page_size: 2 }, iter.params)
    assert_equal 'data', iter.data_key
    assert_equal [], @mock.journal
  end

  def test_resource_paginate_walks_all_pages_following_cursor
    stage_two_page_scenario

    # Page through the list endpoint via the resource accessor — two pages,
    # cursor followed from page 1's links.next into page 2's request.
    collected = @client.fabric.addresses.paginate.to_a

    assert_equal(%w[addr-1 addr-2 addr-3], collected.map { |x| x['id'] })
    assert_two_paginated_gets
  end
end
