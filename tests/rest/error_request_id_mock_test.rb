# frozen_string_literal: true

# 6.6 error-observability: SignalWireRestError exposes the response headers and
# the platform request id (pulled from x-request-id / x-signalwire-request-id /
# request-id / x-amzn-requestid, appended to the message). No wire change —
# client-side observability only. Driven against the real mock, which echoes a
# scenario's response headers.

require 'minitest/autorun'
require_relative 'mock_test'

class ErrorRequestIdMockTest < Minitest::Test
  parallelize_me!

  ADDRESSES_ENDPOINT_ID = 'fabric.list_fabric_addresses'

  def setup
    h = MockTest.client
    @client = h[:client]
    @mock   = h[:mock]
  end

  def raise_with_headers(headers)
    @mock.push_scenario(ADDRESSES_ENDPOINT_ID, status: 404, response: { 'error' => 'nope' },
                                               headers: headers)
    assert_raises(SignalWire::REST::SignalWireRestError) { @client.fabric.addresses.list }
  end

  def test_request_id_from_x_request_id_header
    err = raise_with_headers('x-request-id' => 'req-abc-123')

    assert_equal 'req-abc-123', err.request_id
    assert_match(/request-id: req-abc-123/, err.message)
  end

  def test_headers_are_exposed
    err = raise_with_headers('x-request-id' => 'req-xyz', 'x-custom' => 'v')

    refute_nil err.headers
    # Header capture is case-insensitive on lookup; the map carries what the mock sent.
    assert(err.headers.any? { |k, v| k.to_s.downcase == 'x-custom' && v == 'v' })
  end

  def test_request_id_nil_when_no_id_header
    err = raise_with_headers('content-type' => 'application/json')

    assert_nil err.request_id
    refute_match(/request-id:/, err.message)
  end
end
