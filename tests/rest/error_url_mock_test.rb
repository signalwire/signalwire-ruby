# frozen_string_literal: true

# D1 (owner-approved, FINAL): SignalWireRestError#url must be the FULL request URL
# — scheme + host + path AND the query string — not the bare path. The Python
# reference already stores the full URL; ruby is rippling to match so the
# value-based url check (diff_port_envelope: ruby url=path → url=FULL) holds.
#
# Driven against the real mock so the URL asserted is the one that actually went
# on the wire, not a transport fake.

require 'minitest/autorun'
require_relative 'mock_test'

class ErrorUrlMockTest < Minitest::Test
  parallelize_me!

  ADDRESSES_PATH = '/api/fabric/addresses'
  ADDRESSES_ENDPOINT_ID = 'fabric.list_fabric_addresses'

  def setup
    h = MockTest.client
    @client = h[:client]
    @mock   = h[:mock]
  end

  # Stage a 404 on the addresses endpoint and return the raised error's URI.
  def error_uri(**params)
    @mock.push_scenario(ADDRESSES_ENDPOINT_ID, status: 404, response: { 'error' => 'nope' })
    err = assert_raises(SignalWire::REST::SignalWireRestError) do
      @client.fabric.addresses.list(**params)
    end
    [err, URI.parse(err.url)]
  end

  def test_error_url_is_absolute_with_host
    err, uri = error_uri
    origin = "#{uri.scheme}://#{uri.host}:#{uri.port}"

    # Absolute (scheme+host), points at the origin we called, path preserved.
    assert_equal @mock.url, origin, "error.url must be the full request URL: #{err.url.inspect}"
    assert_equal ADDRESSES_PATH, uri.path, "error.url must include the request path: #{err.url.inspect}"
  end

  def test_error_url_preserves_query_string
    # page_size is a real query param on the list endpoint; it must survive into
    # the error's url (the whole point of "full URL WITH query").
    err, uri = error_uri(page_size: 7)
    query = URI.decode_www_form(uri.query || '').to_h

    assert_equal '7', query['page_size'], "error.url must preserve the query: #{err.url.inspect}"
  end
end
