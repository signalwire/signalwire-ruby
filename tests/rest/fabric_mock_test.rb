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

class FabricMockTest < Minitest::Test
  FABRIC_BASE = '/api/fabric'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- Fabric Addresses -----------------------------------------------

  def test_addresses_list_returns_data_collection
    body = @client.fabric.addresses.list
    assert_kind_of Hash, body
    # Fabric addresses list returns 'data' arrays.
    assert(body.key?('data'),
           "missing 'data' in body keys #{body.keys.sort.inspect}")
    assert_kind_of Array, body['data']

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    assert_equal "#{FABRIC_BASE}/addresses", last.path
    assert_equal 'fabric.list_fabric_addresses', last.matched_route
  end

  def test_addresses_get_uses_address_id
    body = @client.fabric.addresses.get('addr-9001')
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    assert_equal "#{FABRIC_BASE}/addresses/addr-9001", last.path
    refute_nil last.matched_route, 'spec gap: address get'
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
    body = @client.fabric.call_flows.list_addresses('cf-1')
    assert_kind_of Hash, body
    assert(body.key?('data') && body['data'].is_a?(Array))

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    # singular 'call_flow' (NOT 'call_flows') in the addresses sub-path.
    assert_equal "#{FABRIC_BASE}/resources/call_flow/cf-1/addresses", last.path
    refute_nil last.matched_route, 'spec gap: call-flow addresses sub-path'
  end

  # ---- ConferenceRoomsResource.list_addresses — singular path ---------

  def test_conference_rooms_list_addresses_uses_singular_path
    body = @client.fabric.conference_rooms.list_addresses('cr-1')
    assert_kind_of Hash, body
    assert body.key?('data')

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    # singular 'conference_room'.
    assert_equal "#{FABRIC_BASE}/resources/conference_room/cr-1/addresses", last.path
    refute_nil last.matched_route
  end

  # ---- Subscribers — SIP endpoint per-id ops --------------------------

  def test_subscribers_get_sip_endpoint
    body = @client.fabric.subscribers.get_sip_endpoint('sub-1', 'ep-1')
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    assert_equal "#{FABRIC_BASE}/resources/subscribers/sub-1/sip_endpoints/ep-1", last.path
    refute_nil last.matched_route
  end

  def test_subscribers_update_sip_endpoint_uses_patch
    body = @client.fabric.subscribers.update_sip_endpoint(
      'sub-1', 'ep-1', username: 'renamed',
    )
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'PATCH', last.method
    assert_equal "#{FABRIC_BASE}/resources/subscribers/sub-1/sip_endpoints/ep-1", last.path
    assert_kind_of Hash, last.body
    assert_equal 'renamed', last.body['username']
  end

  def test_subscribers_delete_sip_endpoint
    body = @client.fabric.subscribers.delete_sip_endpoint('sub-1', 'ep-1')
    assert_kind_of Hash, body  # SDK normalises 204 to {}

    last = MockTest.journal.last
    assert_equal 'DELETE', last.method
    assert_equal "#{FABRIC_BASE}/resources/subscribers/sub-1/sip_endpoints/ep-1", last.path
    refute_nil last.matched_route
  end

  # ---- FabricTokens — every token-creation endpoint -------------------

  def test_tokens_create_invite_token
    body = @client.fabric.tokens.create_invite_token(email: 'invitee@example.com')
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    # subscriber/invites uses the singular 'subscriber' path segment.
    assert_equal "#{FABRIC_BASE}/subscriber/invites", last.path
    assert_kind_of Hash, last.body
    assert_equal 'invitee@example.com', last.body['email']
  end

  def test_tokens_create_embed_token
    body = @client.fabric.tokens.create_embed_token(
      allowed_addresses: %w[addr-1 addr-2],
    )
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal "#{FABRIC_BASE}/embeds/tokens", last.path
    assert_kind_of Hash, last.body
    assert_equal %w[addr-1 addr-2], last.body['allowed_addresses']
  end

  def test_tokens_refresh_subscriber_token
    body = @client.fabric.tokens.refresh_subscriber_token(refresh_token: 'abc-123')
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal "#{FABRIC_BASE}/subscribers/tokens/refresh", last.path
    assert_kind_of Hash, last.body
    assert_equal 'abc-123', last.body['refresh_token']
  end

  # ---- GenericResources -----------------------------------------------

  def test_resources_list_returns_data_collection
    body = @client.fabric.resources.list
    assert_kind_of Hash, body
    # /api/fabric/resources returns data array.
    assert(body.key?('data') && body['data'].is_a?(Array))

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    assert_equal "#{FABRIC_BASE}/resources", last.path
    refute_nil last.matched_route
  end

  def test_resources_get_returns_single_resource
    body = @client.fabric.resources.get('res-1')
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    assert_equal "#{FABRIC_BASE}/resources/res-1", last.path
  end

  def test_resources_delete
    body = @client.fabric.resources.delete('res-2')
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'DELETE', last.method
    assert_equal "#{FABRIC_BASE}/resources/res-2", last.path
    refute_nil last.matched_route
  end

  def test_resources_list_addresses
    body = @client.fabric.resources.list_addresses('res-3')
    assert_kind_of Hash, body
    assert(body.key?('data') && body['data'].is_a?(Array))

    last = MockTest.journal.last
    assert_equal 'GET', last.method
    assert_equal "#{FABRIC_BASE}/resources/res-3/addresses", last.path
  end

  def test_resources_assign_domain_application
    body = @client.fabric.resources.assign_domain_application(
      'res-4', domain_application_id: 'da-7',
    )
    assert_kind_of Hash, body

    last = MockTest.journal.last
    assert_equal 'POST', last.method
    assert_equal "#{FABRIC_BASE}/resources/res-4/domain_applications", last.path
    assert_kind_of Hash, last.body
    assert_equal 'da-7', last.body['domain_application_id']
  end
end
