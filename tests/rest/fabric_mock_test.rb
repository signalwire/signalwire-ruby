# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_fabric_mock.py.
#
# Closes the audit gaps the legacy fabric tests leave open: addresses,
# generic resources operations, SIP-endpoint sub-resources on subscribers,
# the call-flows / conference-rooms addresses sub-paths, the full
# FabricTokens surface, and the cxml_applications.create deliberate-failure
# path.

require 'minitest/autorun'
require_relative 'mock_test'

# Shared fixture + journal/collection assertion helpers for the Fabric mock
# test classes below.
module FabricMockHelpers
  FABRIC_BASE = '/api/fabric'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # Assert the last journalled request's method + path, and optionally that a
  # route matched (+:matched+) or the exact matched_route id. Returns the
  # journal entry for any further per-field assertions.
  def assert_last_request(method, path, route: nil)
    last = MockTest.journal.last

    assert_equal method, last.method
    assert_equal path, last.path
    assert_route(last, route)
    last
  end

  def assert_route(entry, route)
    case route
    when :matched then refute_nil entry.matched_route
    when nil then nil # caller doesn't assert on the route

    else assert_equal route, entry.matched_route
    end
  end

  # Assert the body is a Hash with a 'data' Array.
  def assert_data_collection(body)
    assert_kind_of Hash, body
    assert(body.key?('data'), "missing 'data' in body keys #{body.keys.sort.inspect}")
    assert_kind_of Array, body['data']
  end
end

class FabricMockTest < Minitest::Test
  include FabricMockHelpers

  # ---- Fabric Addresses -----------------------------------------------

  def test_addresses_list_returns_data_collection
    assert_data_collection(@client.fabric.addresses.list)
    assert_last_request('GET', "#{FABRIC_BASE}/addresses", route: 'fabric.list_fabric_addresses')
  end

  def test_addresses_get_uses_address_id
    assert_kind_of Hash, @client.fabric.addresses.get('addr-9001')
    assert_last_request('GET', "#{FABRIC_BASE}/addresses/addr-9001", route: :matched)
  end

  # ---- CxmlApplicationsResource.create raises NotImplementedError -----

  def test_cxml_applications_create_raises_not_implemented
    err = assert_raises(NotImplementedError) do
      @client.fabric.cxml_applications.create(name: 'never_built')
    end
    assert_match(/cXML applications cannot/, err.message)
    # Nothing should have hit the wire.
    assert_equal [], MockTest.journal.journal
  end

  # ---- CallFlowsResource.list_addresses — singular path ---------------

  def test_call_flows_list_addresses_uses_singular_path
    assert_data_collection(@client.fabric.call_flows.list_addresses('cf-1'))
    # singular 'call_flow' (NOT 'call_flows') in the addresses sub-path.
    assert_last_request('GET', "#{FABRIC_BASE}/resources/call_flow/cf-1/addresses", route: :matched)
  end

  # ---- ConferenceRoomsResource.list_addresses — singular path ---------

  def test_conference_rooms_list_addresses_uses_singular_path
    body = @client.fabric.conference_rooms.list_addresses('cr-1')

    assert_kind_of Hash, body
    assert body.key?('data')
    # singular 'conference_room'.
    assert_last_request('GET', "#{FABRIC_BASE}/resources/conference_room/cr-1/addresses",
                        route: :matched)
  end

  # ---- Subscribers — SIP endpoint per-id ops --------------------------

  def test_subscribers_get_sip_endpoint
    assert_kind_of Hash, @client.fabric.subscribers.get_sip_endpoint('sub-1', 'ep-1')
    assert_last_request('GET', "#{FABRIC_BASE}/resources/subscribers/sub-1/sip_endpoints/ep-1",
                        route: :matched)
  end

  def test_subscribers_update_sip_endpoint_uses_patch
    body = @client.fabric.subscribers.update_sip_endpoint('sub-1', 'ep-1', username: 'renamed')

    assert_kind_of Hash, body
    last = assert_last_request('PATCH',
                               "#{FABRIC_BASE}/resources/subscribers/sub-1/sip_endpoints/ep-1")
    assert_kind_of Hash, last.body
    assert_equal 'renamed', last.body['username']
  end

  def test_subscribers_delete_sip_endpoint
    assert_kind_of Hash, @client.fabric.subscribers.delete_sip_endpoint('sub-1', 'ep-1') # 204 -> {}
    assert_last_request('DELETE', "#{FABRIC_BASE}/resources/subscribers/sub-1/sip_endpoints/ep-1",
                        route: :matched)
  end

  # ---- FabricTokens — every token-creation endpoint -------------------

  def test_tokens_create_invite_token
    body = @client.fabric.tokens.create_invite_token(email: 'invitee@example.com')

    assert_kind_of Hash, body
    # subscriber/invites uses the singular 'subscriber' path segment.
    last = assert_last_request('POST', "#{FABRIC_BASE}/subscriber/invites")
    assert_kind_of Hash, last.body
    assert_equal 'invitee@example.com', last.body['email']
  end

  def test_tokens_create_embed_token
    body = @client.fabric.tokens.create_embed_token(allowed_addresses: %w[addr-1 addr-2])

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{FABRIC_BASE}/embeds/tokens")
    assert_kind_of Hash, last.body
    assert_equal %w[addr-1 addr-2], last.body['allowed_addresses']
  end

  def test_tokens_refresh_subscriber_token
    body = @client.fabric.tokens.refresh_subscriber_token(refresh_token: 'abc-123')

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{FABRIC_BASE}/subscribers/tokens/refresh")
    assert_kind_of Hash, last.body
    assert_equal 'abc-123', last.body['refresh_token']
  end
end

# GenericResources operations. Split from FabricMockTest to keep each class
# within budget.
class FabricResourcesMockTest < Minitest::Test
  include FabricMockHelpers

  def test_resources_list_returns_data_collection
    # /api/fabric/resources returns data array.
    assert_data_collection(@client.fabric.resources.list)
    assert_last_request('GET', "#{FABRIC_BASE}/resources", route: :matched)
  end

  def test_resources_get_returns_single_resource
    assert_kind_of Hash, @client.fabric.resources.get('res-1')
    assert_last_request('GET', "#{FABRIC_BASE}/resources/res-1")
  end

  def test_resources_delete
    assert_kind_of Hash, @client.fabric.resources.delete('res-2')
    assert_last_request('DELETE', "#{FABRIC_BASE}/resources/res-2", route: :matched)
  end

  def test_resources_list_addresses
    assert_data_collection(@client.fabric.resources.list_addresses('res-3'))
    assert_last_request('GET', "#{FABRIC_BASE}/resources/res-3/addresses")
  end

  def test_resources_assign_domain_application
    body = @client.fabric.resources.assign_domain_application('res-4', domain_application_id: 'da-7')

    assert_kind_of Hash, body
    last = assert_last_request('POST', "#{FABRIC_BASE}/resources/res-4/domain_applications")
    assert_kind_of Hash, last.body
    assert_equal 'da-7', last.body['domain_application_id']
  end
end
