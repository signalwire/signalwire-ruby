# frozen_string_literal: true

# Full success+error REST coverage for the `fabric` spec group.
#
# Every canonical fabric route (96 coverable of 103) gets a SUCCESS (2xx) test
# AND an ERROR (non-2xx, via push_scenario) test on the correct path, so the
# porting-sdk rest_coverage checker marks each route fully covered. The 7
# accepted gaps are dialogflow_agents (5 routes -- no Ruby accessor) and the two
# doubled-path routes (list_sip_gateway_addresses, assign_resource_sip_endpoint).
#
# Mirrors the idiom of tests/rest/fabric_mock_test.rb (MockTest.client ->
# {client:, mock:, project:}; @mock.last journal asserts; push_scenario(id,
# status:, response:) for errors; assert_raises(SignalWire::REST::
# SignalWireRestError) + err.status_code). Classes are split per-resource to
# stay under the Metrics/ClassLength floor, matching the existing layout.

require 'minitest/autorun'
require_relative 'mock_test'

# Shared fixture + assertion helpers for the fabric coverage classes below.
module FabricCoverageHelpers
  FABRIC_BASE = '/api/fabric'
  RES = "#{FABRIC_BASE}/resources".freeze

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  # Assert the last journalled request's method + path + matched_route.
  def assert_request(method, path, route)
    last = @mock.last

    assert_equal method, last.method
    assert_equal path, last.path
    assert_equal route, last.matched_route
    last
  end

  # Assert a list/collection body. The mock's example payloads are sometimes a
  # bare JSON array and sometimes the paginated +{'data' => [...]}+ envelope;
  # accept either so the assertion exercises the route without over-constraining
  # the (mock-supplied) response shape.
  def assert_listing(body)
    if body.is_a?(Hash)
      assert body.key?('data'), "list body Hash missing 'data': #{body.keys.sort.inspect}"
    else
      assert_kind_of Array, body
    end
  end

  # Stage a one-shot error for endpoint_id, run the block, assert it raises a
  # SignalWireRestError carrying status, and that the journal recorded it.
  def assert_error(endpoint_id, status: 404, &)
    @mock.push_scenario(endpoint_id, status: status, response: { 'error' => 'boom' })
    err = assert_raises(SignalWire::REST::SignalWireRestError, &)

    assert_equal status, err.status_code
    assert_equal status, @mock.last.response_status
    assert_equal endpoint_id, @mock.last.matched_route
    err
  end

  # Shared CRUD+addresses success coverage for a FabricResource accessor whose
  # paths are the standard {base}/{type}[/{id}[/addresses]] shape. +acc+ is the
  # accessor symbol (e.g. :ai_agents), +seg+ the URL segment, +rid+ the route-id
  # stem (e.g. 'ai_agent'); +verb+ is the HTTP method the spec mandates for
  # update (PATCH or PUT).
  module CrudWithAddresses
    def crud_list(acc, seg, rid)
      assert_listing(@client.fabric.public_send(acc).list)
      assert_request('GET', "#{RES}/#{seg}", "fabric.list_#{rid}s")
    end

    def crud_create(acc, seg, rid, key:, val:)
      assert_kind_of Hash, @client.fabric.public_send(acc).create(**{ key => val })
      last = assert_request('POST', "#{RES}/#{seg}", "fabric.create_#{rid}")
      assert_equal val, last.body[key.to_s]
    end

    def crud_get(acc, seg, rid, id)
      assert_kind_of Hash, @client.fabric.public_send(acc).get(id)
      assert_request('GET', "#{RES}/#{seg}/#{id}", "fabric.get_#{rid}")
    end

    def crud_update(acc, seg, rid, id, verb, key:, val:)
      assert_kind_of Hash, @client.fabric.public_send(acc).update(id, **{ key => val })
      last = assert_request(verb, "#{RES}/#{seg}/#{id}", "fabric.update_#{rid}")
      assert_equal val, last.body[key.to_s]
    end

    def crud_delete(acc, seg, rid, id)
      assert_kind_of Hash, @client.fabric.public_send(acc).delete(id)
      assert_request('DELETE', "#{RES}/#{seg}/#{id}", "fabric.delete_#{rid}")
    end

    def crud_list_addresses(acc, seg, rid, id)
      assert_listing(@client.fabric.public_send(acc).list_addresses(id))
      assert_request('GET', "#{RES}/#{seg}/#{id}/addresses", "fabric.list_#{rid}_addresses")
    end
  end
end

# ---- ai_agents (update = PATCH) ---------------------------------------
class FabricAiAgentsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:ai_agents, 'ai_agents', 'ai_agent')
  def test_list_error = assert_error('fabric.list_ai_agents') { @client.fabric.ai_agents.list }
  def test_create_success = crud_create(:ai_agents, 'ai_agents', 'ai_agent', key: :name, val: 'a')

  def test_create_error
    assert_error('fabric.create_ai_agent', status: 422) { @client.fabric.ai_agents.create(name: 'a') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:ai_agents, 'ai_agents', 'ai_agent', 'aa-1')
  def test_get_error = assert_error('fabric.get_ai_agent') { @client.fabric.ai_agents.get('aa-1') }
  def test_update_success = crud_update(:ai_agents, 'ai_agents', 'ai_agent', 'aa-1', 'PATCH', key: :name, val: 'b')

  def test_update_error
    assert_error('fabric.update_ai_agent') { @client.fabric.ai_agents.update('aa-1', name: 'b') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:ai_agents, 'ai_agents', 'ai_agent', 'aa-1')
  def test_delete_error = assert_error('fabric.delete_ai_agent') { @client.fabric.ai_agents.delete('aa-1') }
  def test_list_addresses_success = crud_list_addresses(:ai_agents, 'ai_agents', 'ai_agent', 'aa-1')

  def test_list_addresses_error
    assert_error('fabric.list_ai_agent_addresses') { @client.fabric.ai_agents.list_addresses('aa-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- sip_endpoints (update = PUT) -------------------------------------
class FabricSipEndpointsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:sip_endpoints, 'sip_endpoints', 'sip_endpoint')
  def test_list_error = assert_error('fabric.list_sip_endpoints') { @client.fabric.sip_endpoints.list }
  def test_create_success = crud_create(:sip_endpoints, 'sip_endpoints', 'sip_endpoint', key: :username, val: 'u')

  def test_create_error
    assert_error('fabric.create_sip_endpoint', status: 422) { @client.fabric.sip_endpoints.create(username: 'u') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:sip_endpoints, 'sip_endpoints', 'sip_endpoint', 'se-1')
  def test_get_error = assert_error('fabric.get_sip_endpoint') { @client.fabric.sip_endpoints.get('se-1') }

  def test_update_success
    crud_update(:sip_endpoints, 'sip_endpoints', 'sip_endpoint', 'se-1', 'PUT', key: :username, val: 'v')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_sip_endpoint') { @client.fabric.sip_endpoints.update('se-1', username: 'v') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:sip_endpoints, 'sip_endpoints', 'sip_endpoint', 'se-1')
  def test_delete_error = assert_error('fabric.delete_sip_endpoint') { @client.fabric.sip_endpoints.delete('se-1') }

  def test_list_addresses_success
    crud_list_addresses(:sip_endpoints, 'sip_endpoints', 'sip_endpoint', 'se-1')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_list_addresses_error
    assert_error('fabric.list_sip_endpoint_addresses') { @client.fabric.sip_endpoints.list_addresses('se-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- sip_gateways (update = PATCH; no list_addresses accessor) --------
class FabricSipGatewaysCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:sip_gateways, 'sip_gateways', 'sip_gateway')
  def test_list_error = assert_error('fabric.list_sip_gateways') { @client.fabric.sip_gateways.list }
  def test_create_success = crud_create(:sip_gateways, 'sip_gateways', 'sip_gateway', key: :name, val: 'g')

  def test_create_error
    assert_error('fabric.create_sip_gateway', status: 422) { @client.fabric.sip_gateways.create(name: 'g') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:sip_gateways, 'sip_gateways', 'sip_gateway', 'sg-1')
  def test_get_error = assert_error('fabric.get_sip_gateway') { @client.fabric.sip_gateways.get('sg-1') }

  def test_update_success
    crud_update(:sip_gateways, 'sip_gateways', 'sip_gateway', 'sg-1', 'PATCH', key: :name,
                                                                               val: 'h')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_sip_gateway') { @client.fabric.sip_gateways.update('sg-1', name: 'h') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:sip_gateways, 'sip_gateways', 'sip_gateway', 'sg-1')
  def test_delete_error = assert_error('fabric.delete_sip_gateway') { @client.fabric.sip_gateways.delete('sg-1') }
end

# ---- swml_scripts (update = PUT) --------------------------------------
class FabricSwmlScriptsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:swml_scripts, 'swml_scripts', 'swml_script')
  def test_list_error = assert_error('fabric.list_swml_scripts') { @client.fabric.swml_scripts.list }
  def test_create_success = crud_create(:swml_scripts, 'swml_scripts', 'swml_script', key: :name, val: 's')

  def test_create_error
    assert_error('fabric.create_swml_script', status: 422) { @client.fabric.swml_scripts.create(name: 's') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:swml_scripts, 'swml_scripts', 'swml_script', 'ss-1')
  def test_get_error = assert_error('fabric.get_swml_script') { @client.fabric.swml_scripts.get('ss-1') }

  def test_update_success
    crud_update(:swml_scripts, 'swml_scripts', 'swml_script', 'ss-1', 'PUT', key: :name,
                                                                             val: 't')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_swml_script') { @client.fabric.swml_scripts.update('ss-1', name: 't') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:swml_scripts, 'swml_scripts', 'swml_script', 'ss-1')
  def test_delete_error = assert_error('fabric.delete_swml_script') { @client.fabric.swml_scripts.delete('ss-1') }
  def test_list_addresses_success = crud_list_addresses(:swml_scripts, 'swml_scripts', 'swml_script', 'ss-1')

  def test_list_addresses_error
    assert_error('fabric.list_swml_script_addresses') { @client.fabric.swml_scripts.list_addresses('ss-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- cxml_scripts (update = PUT) --------------------------------------
class FabricCxmlScriptsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:cxml_scripts, 'cxml_scripts', 'cxml_script')
  def test_list_error = assert_error('fabric.list_cxml_scripts') { @client.fabric.cxml_scripts.list }
  def test_create_success = crud_create(:cxml_scripts, 'cxml_scripts', 'cxml_script', key: :name, val: 'c')

  def test_create_error
    assert_error('fabric.create_cxml_script', status: 422) { @client.fabric.cxml_scripts.create(name: 'c') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:cxml_scripts, 'cxml_scripts', 'cxml_script', 'cs-1')
  def test_get_error = assert_error('fabric.get_cxml_script') { @client.fabric.cxml_scripts.get('cs-1') }

  def test_update_success
    crud_update(:cxml_scripts, 'cxml_scripts', 'cxml_script', 'cs-1', 'PUT', key: :name,
                                                                             val: 'd')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_cxml_script') { @client.fabric.cxml_scripts.update('cs-1', name: 'd') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:cxml_scripts, 'cxml_scripts', 'cxml_script', 'cs-1')
  def test_delete_error = assert_error('fabric.delete_cxml_script') { @client.fabric.cxml_scripts.delete('cs-1') }
  def test_list_addresses_success = crud_list_addresses(:cxml_scripts, 'cxml_scripts', 'cxml_script', 'cs-1')

  def test_list_addresses_error
    assert_error('fabric.list_cxml_script_addresses') { @client.fabric.cxml_scripts.list_addresses('cs-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- freeswitch_connectors (update = PUT) -----------------------------
class FabricFreeswitchConnectorsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:freeswitch_connectors, 'freeswitch_connectors', 'freeswitch_connector')

  def test_list_error
    assert_error('fabric.list_freeswitch_connectors') { @client.fabric.freeswitch_connectors.list }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_create_success
    crud_create(:freeswitch_connectors, 'freeswitch_connectors', 'freeswitch_connector', key: :name, val: 'f')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_create_error
    assert_error('fabric.create_freeswitch_connector', status: 422) do
      @client.fabric.freeswitch_connectors.create(name: 'f')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:freeswitch_connectors, 'freeswitch_connectors', 'freeswitch_connector', 'fc-1')

  def test_get_error
    assert_error('fabric.get_freeswitch_connector') { @client.fabric.freeswitch_connectors.get('fc-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_update_success
    crud_update(:freeswitch_connectors, 'freeswitch_connectors', 'freeswitch_connector', 'fc-1', 'PUT',
                key: :name, val: 'g')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_freeswitch_connector') do
      @client.fabric.freeswitch_connectors.update('fc-1', name: 'g')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success
    crud_delete(:freeswitch_connectors, 'freeswitch_connectors', 'freeswitch_connector', 'fc-1')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_delete_error
    assert_error('fabric.delete_freeswitch_connector') { @client.fabric.freeswitch_connectors.delete('fc-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_list_addresses_success
    crud_list_addresses(:freeswitch_connectors, 'freeswitch_connectors', 'freeswitch_connector', 'fc-1')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_list_addresses_error
    assert_error('fabric.list_freeswitch_connector_addresses') do
      @client.fabric.freeswitch_connectors.list_addresses('fc-1')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- relay_applications (update = PUT) --------------------------------
class FabricRelayApplicationsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:relay_applications, 'relay_applications', 'relay_application')
  def test_list_error = assert_error('fabric.list_relay_applications') { @client.fabric.relay_applications.list }

  def test_create_success
    crud_create(:relay_applications, 'relay_applications', 'relay_application', key: :name, val: 'r')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_create_error
    assert_error('fabric.create_relay_application', status: 422) { @client.fabric.relay_applications.create(name: 'r') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:relay_applications, 'relay_applications', 'relay_application', 'ra-1')
  def test_get_error = assert_error('fabric.get_relay_application') { @client.fabric.relay_applications.get('ra-1') }

  def test_update_success
    crud_update(:relay_applications, 'relay_applications', 'relay_application', 'ra-1', 'PUT', key: :name, val: 's')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_relay_application') { @client.fabric.relay_applications.update('ra-1', name: 's') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:relay_applications, 'relay_applications', 'relay_application', 'ra-1')

  def test_delete_error
    assert_error('fabric.delete_relay_application') { @client.fabric.relay_applications.delete('ra-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_list_addresses_success
    crud_list_addresses(:relay_applications, 'relay_applications', 'relay_application', 'ra-1')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_list_addresses_error
    assert_error('fabric.list_relay_application_addresses') do
      @client.fabric.relay_applications.list_addresses('ra-1')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- swml_webhooks (update = PATCH; create deprecation-warns) ---------
class FabricSwmlWebhooksCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:swml_webhooks, 'swml_webhooks', 'swml_webhook')
  def test_list_error = assert_error('fabric.list_swml_webhooks') { @client.fabric.swml_webhooks.list }

  def test_create_success
    body = nil
    _out, err = capture_io { body = @client.fabric.swml_webhooks.create(name: 'w') }

    assert_match(/DEPRECATION/, err)
    assert_kind_of Hash, body
    last = assert_request('POST', "#{RES}/swml_webhooks", 'fabric.create_swml_webhook')
    assert_equal 'w', last.body['name']
  end

  def test_create_error
    capture_io do
      assert_error('fabric.create_swml_webhook', status: 422) { @client.fabric.swml_webhooks.create(name: 'w') }
    end
  end

  def test_get_success = crud_get(:swml_webhooks, 'swml_webhooks', 'swml_webhook', 'sw-1')
  def test_get_error = assert_error('fabric.get_swml_webhook') { @client.fabric.swml_webhooks.get('sw-1') }

  def test_update_success
    crud_update(:swml_webhooks, 'swml_webhooks', 'swml_webhook', 'sw-1', 'PATCH', key: :name,
                                                                                  val: 'x')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_swml_webhook') { @client.fabric.swml_webhooks.update('sw-1', name: 'x') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:swml_webhooks, 'swml_webhooks', 'swml_webhook', 'sw-1')
  def test_delete_error = assert_error('fabric.delete_swml_webhook') { @client.fabric.swml_webhooks.delete('sw-1') }
  def test_list_addresses_success = crud_list_addresses(:swml_webhooks, 'swml_webhooks', 'swml_webhook', 'sw-1')

  def test_list_addresses_error
    assert_error('fabric.list_swml_webhook_addresses') { @client.fabric.swml_webhooks.list_addresses('sw-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- cxml_webhooks (update = PATCH; create deprecation-warns) ---------
class FabricCxmlWebhooksCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:cxml_webhooks, 'cxml_webhooks', 'cxml_webhook')
  def test_list_error = assert_error('fabric.list_cxml_webhooks') { @client.fabric.cxml_webhooks.list }

  def test_create_success
    body = nil
    _out, err = capture_io { body = @client.fabric.cxml_webhooks.create(name: 'cw') }

    assert_match(/DEPRECATION/, err)
    assert_kind_of Hash, body
    last = assert_request('POST', "#{RES}/cxml_webhooks", 'fabric.create_cxml_webhook')
    assert_equal 'cw', last.body['name']
  end

  def test_create_error
    capture_io do
      assert_error('fabric.create_cxml_webhook', status: 422) { @client.fabric.cxml_webhooks.create(name: 'cw') }
    end
  end

  def test_get_success = crud_get(:cxml_webhooks, 'cxml_webhooks', 'cxml_webhook', 'cw-1')
  def test_get_error = assert_error('fabric.get_cxml_webhook') { @client.fabric.cxml_webhooks.get('cw-1') }

  def test_update_success
    crud_update(:cxml_webhooks, 'cxml_webhooks', 'cxml_webhook', 'cw-1', 'PATCH', key: :name,
                                                                                  val: 'cx')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_cxml_webhook') { @client.fabric.cxml_webhooks.update('cw-1', name: 'cx') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:cxml_webhooks, 'cxml_webhooks', 'cxml_webhook', 'cw-1')
  def test_delete_error = assert_error('fabric.delete_cxml_webhook') { @client.fabric.cxml_webhooks.delete('cw-1') }
  def test_list_addresses_success = crud_list_addresses(:cxml_webhooks, 'cxml_webhooks', 'cxml_webhook', 'cw-1')

  def test_list_addresses_error
    assert_error('fabric.list_cxml_webhook_addresses') { @client.fabric.cxml_webhooks.list_addresses('cw-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- cxml_applications (no create; update = PUT) ----------------------
class FabricCxmlApplicationsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_create_raises_not_implemented
    err = assert_raises(NotImplementedError) { @client.fabric.cxml_applications.create(name: 'nope') }

    assert_match(/cXML applications cannot/, err.message)
    assert_equal [], @mock.journal
  end

  def test_list_success = crud_list(:cxml_applications, 'cxml_applications', 'cxml_application')
  def test_list_error = assert_error('fabric.list_cxml_applications') { @client.fabric.cxml_applications.list }
  def test_get_success = crud_get(:cxml_applications, 'cxml_applications', 'cxml_application', 'ca-1')
  def test_get_error = assert_error('fabric.get_cxml_application') { @client.fabric.cxml_applications.get('ca-1') }

  def test_update_success
    crud_update(:cxml_applications, 'cxml_applications', 'cxml_application', 'ca-1', 'PUT', key: :name, val: 'caz')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_cxml_application') { @client.fabric.cxml_applications.update('ca-1', name: 'caz') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:cxml_applications, 'cxml_applications', 'cxml_application', 'ca-1')

  def test_delete_error
    assert_error('fabric.delete_cxml_application') { @client.fabric.cxml_applications.delete('ca-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_list_addresses_success
    crud_list_addresses(:cxml_applications, 'cxml_applications', 'cxml_application', 'ca-1')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_list_addresses_error
    assert_error('fabric.list_cxml_application_addresses') { @client.fabric.cxml_applications.list_addresses('ca-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- call_flows (update = PUT; singular sub-paths + versions) ---------
class FabricCallFlowsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:call_flows, 'call_flows', 'call_flow')
  def test_list_error = assert_error('fabric.list_call_flows') { @client.fabric.call_flows.list }
  def test_create_success = crud_create(:call_flows, 'call_flows', 'call_flow', key: :name, val: 'cf')

  def test_create_error
    assert_error('fabric.create_call_flow', status: 422) { @client.fabric.call_flows.create(name: 'cf') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:call_flows, 'call_flows', 'call_flow', 'cf-1')
  def test_get_error = assert_error('fabric.get_call_flow') { @client.fabric.call_flows.get('cf-1') }
  def test_update_success = crud_update(:call_flows, 'call_flows', 'call_flow', 'cf-1', 'PUT', key: :name, val: 'cfz')

  def test_update_error
    assert_error('fabric.update_call_flow') { @client.fabric.call_flows.update('cf-1', name: 'cfz') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:call_flows, 'call_flows', 'call_flow', 'cf-1')
  def test_delete_error = assert_error('fabric.delete_call_flow') { @client.fabric.call_flows.delete('cf-1') }

  # singular 'call_flow' segment for the sub-paths.
  def test_list_addresses_success
    assert_listing(@client.fabric.call_flows.list_addresses('cf-1'))
    assert_request('GET', "#{RES}/call_flow/cf-1/addresses", 'fabric.list_call_flow_addresses')
  end

  def test_list_addresses_error
    assert_error('fabric.list_call_flow_addresses') { @client.fabric.call_flows.list_addresses('cf-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_list_versions_success
    assert_kind_of Hash, @client.fabric.call_flows.list_versions('cf-1')
    assert_request('GET', "#{RES}/call_flow/cf-1/versions", 'fabric.list_call_flow_versions')
  end

  def test_list_versions_error
    assert_error('fabric.list_call_flow_versions') { @client.fabric.call_flows.list_versions('cf-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_deploy_version_success
    assert_kind_of Hash, @client.fabric.call_flows.deploy_version('cf-1', version_id: 'v1')
    last = assert_request('POST', "#{RES}/call_flow/cf-1/versions", 'fabric.deploy_call_flow_version')
    assert_equal 'v1', last.body['version_id']
  end

  def test_deploy_version_error
    assert_error('fabric.deploy_call_flow_version', status: 422) do
      @client.fabric.call_flows.deploy_version('cf-1', version_id: 'v1')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- conference_rooms (update = PUT; singular addresses sub-path) -----
class FabricConferenceRoomsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:conference_rooms, 'conference_rooms', 'conference_room')
  def test_list_error = assert_error('fabric.list_conference_rooms') { @client.fabric.conference_rooms.list }

  def test_create_success
    crud_create(:conference_rooms, 'conference_rooms', 'conference_room', key: :name, val: 'cr')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_create_error
    assert_error('fabric.create_conference_room', status: 422) { @client.fabric.conference_rooms.create(name: 'cr') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:conference_rooms, 'conference_rooms', 'conference_room', 'cr-1')
  def test_get_error = assert_error('fabric.get_conference_room') { @client.fabric.conference_rooms.get('cr-1') }

  def test_update_success
    crud_update(:conference_rooms, 'conference_rooms', 'conference_room', 'cr-1', 'PUT', key: :name, val: 'crz')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_conference_room') { @client.fabric.conference_rooms.update('cr-1', name: 'crz') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:conference_rooms, 'conference_rooms', 'conference_room', 'cr-1')

  def test_delete_error
    assert_error('fabric.delete_conference_room') { @client.fabric.conference_rooms.delete('cr-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  # singular 'conference_room' segment for the addresses sub-path.
  def test_list_addresses_success
    assert_listing(@client.fabric.conference_rooms.list_addresses('cr-1'))
    assert_request('GET', "#{RES}/conference_room/cr-1/addresses", 'fabric.list_conference_room_addresses')
  end

  def test_list_addresses_error
    assert_error('fabric.list_conference_room_addresses') { @client.fabric.conference_rooms.list_addresses('cr-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- subscribers (update = PUT) ---------------------------------------
class FabricSubscribersCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers
  include FabricCoverageHelpers::CrudWithAddresses

  def test_list_success = crud_list(:subscribers, 'subscribers', 'subscriber')
  def test_list_error = assert_error('fabric.list_subscribers') { @client.fabric.subscribers.list }
  def test_create_success = crud_create(:subscribers, 'subscribers', 'subscriber', key: :email, val: 's@e.com')

  def test_create_error
    assert_error('fabric.create_subscriber', status: 422) { @client.fabric.subscribers.create(email: 's@e.com') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success = crud_get(:subscribers, 'subscribers', 'subscriber', 'sub-1')
  def test_get_error = assert_error('fabric.get_subscriber') { @client.fabric.subscribers.get('sub-1') }

  def test_update_success
    crud_update(:subscribers, 'subscribers', 'subscriber', 'sub-1', 'PUT', key: :email, val: 'n@e.com')

    refute_nil @mock.last.matched_route, 'no matched_route recorded'
  end

  def test_update_error
    assert_error('fabric.update_subscriber') { @client.fabric.subscribers.update('sub-1', email: 'n@e.com') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success = crud_delete(:subscribers, 'subscribers', 'subscriber', 'sub-1')
  def test_delete_error = assert_error('fabric.delete_subscriber') { @client.fabric.subscribers.delete('sub-1') }
  def test_list_addresses_success = crud_list_addresses(:subscribers, 'subscribers', 'subscriber', 'sub-1')

  def test_list_addresses_error
    assert_error('fabric.list_subscriber_addresses') { @client.fabric.subscribers.list_addresses('sub-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- subscribers: SIP-endpoint sub-resource operations ----------------
class FabricSubscriberSipEndpointsCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers

  SUB = "#{RES}/subscribers/sub-1/sip_endpoints".freeze

  def test_list_success
    assert_listing(@client.fabric.subscribers.list_sip_endpoints('sub-1'))
    assert_request('GET', SUB, 'fabric.list_subscriber_sip_endpoints')
  end

  def test_list_error
    assert_error('fabric.list_subscriber_sip_endpoints') { @client.fabric.subscribers.list_sip_endpoints('sub-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_create_success
    assert_kind_of Hash, @client.fabric.subscribers.create_sip_endpoint('sub-1', username: 'u')
    last = assert_request('POST', SUB, 'fabric.create_subscriber_sip_endpoint')
    assert_equal 'u', last.body['username']
  end

  def test_create_error
    assert_error('fabric.create_subscriber_sip_endpoint', status: 422) do
      @client.fabric.subscribers.create_sip_endpoint('sub-1', username: 'u')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_get_success
    assert_kind_of Hash, @client.fabric.subscribers.get_sip_endpoint('sub-1', 'ep-1')
    assert_request('GET', "#{SUB}/ep-1", 'fabric.get_subscriber_sip_endpoint')
  end

  def test_get_error
    assert_error('fabric.get_subscriber_sip_endpoint') do
      @client.fabric.subscribers.get_sip_endpoint('sub-1', 'ep-1')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_update_success
    assert_kind_of Hash, @client.fabric.subscribers.update_sip_endpoint('sub-1', 'ep-1', username: 'r')
    last = assert_request('PATCH', "#{SUB}/ep-1", 'fabric.update_subscriber_sip_endpoint')
    assert_equal 'r', last.body['username']
  end

  def test_update_error
    assert_error('fabric.update_subscriber_sip_endpoint') do
      @client.fabric.subscribers.update_sip_endpoint('sub-1', 'ep-1', username: 'r')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_delete_success
    assert_kind_of Hash, @client.fabric.subscribers.delete_sip_endpoint('sub-1', 'ep-1')
    assert_request('DELETE', "#{SUB}/ep-1", 'fabric.delete_subscriber_sip_endpoint')
  end

  def test_delete_error
    assert_error('fabric.delete_subscriber_sip_endpoint') do
      @client.fabric.subscribers.delete_sip_endpoint('sub-1', 'ep-1')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end

# ---- generic resources + read-only addresses --------------------------
class FabricResourcesCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers

  def test_list_success
    assert_listing(@client.fabric.resources.list)
    assert_request('GET', RES, 'fabric.list_resources')
  end

  def test_list_error = assert_error('fabric.list_resources') { @client.fabric.resources.list }

  def test_get_success
    assert_kind_of Hash, @client.fabric.resources.get('res-1')
    assert_request('GET', "#{RES}/res-1", 'fabric.get_resource')
  end

  def test_get_error = assert_error('fabric.get_resource') { @client.fabric.resources.get('res-1') }

  def test_delete_success
    assert_kind_of Hash, @client.fabric.resources.delete('res-1')
    assert_request('DELETE', "#{RES}/res-1", 'fabric.delete_resource')
  end

  def test_delete_error = assert_error('fabric.delete_resource') { @client.fabric.resources.delete('res-1') }

  def test_list_addresses_success
    assert_listing(@client.fabric.resources.list_addresses('res-1'))
    assert_request('GET', "#{RES}/res-1/addresses", 'fabric.list_resource_addresses')
  end

  def test_list_addresses_error
    assert_error('fabric.list_resource_addresses') { @client.fabric.resources.list_addresses('res-1') }
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_assign_phone_route_success
    body = nil
    _out, err = capture_io { body = @client.fabric.resources.assign_phone_route('res-1', target_id: 't-1') }

    assert_match(/DEPRECATION/, err)
    assert_kind_of Hash, body
    last = assert_request('POST', "#{RES}/res-1/phone_routes", 'fabric.assign_resource_phone_route')
    assert_equal 't-1', last.body['target_id']
  end

  def test_assign_phone_route_error
    capture_io do
      assert_error('fabric.assign_resource_phone_route', status: 422) do
        @client.fabric.resources.assign_phone_route('res-1', target_id: 't-1')
      end
    end
  end

  def test_assign_domain_application_success
    assert_kind_of Hash, @client.fabric.resources.assign_domain_application('res-1', domain_application_id: 'da-1')
    last = assert_request('POST', "#{RES}/res-1/domain_applications", 'fabric.assign_resource_domain_application')
    assert_equal 'da-1', last.body['domain_application_id']
  end

  def test_assign_domain_application_error
    assert_error('fabric.assign_resource_domain_application', status: 422) do
      @client.fabric.resources.assign_domain_application('res-1', domain_application_id: 'da-1')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_addresses_list_success
    assert_listing(@client.fabric.addresses.list)
    assert_request('GET', "#{FABRIC_BASE}/addresses", 'fabric.list_fabric_addresses')
  end

  def test_addresses_list_error = assert_error('fabric.list_fabric_addresses') { @client.fabric.addresses.list }

  def test_addresses_get_success
    assert_kind_of Hash, @client.fabric.addresses.get('addr-1')
    assert_request('GET', "#{FABRIC_BASE}/addresses/addr-1", 'fabric.get_fabric_address')
  end

  def test_addresses_get_error = assert_error('fabric.get_fabric_address') { @client.fabric.addresses.get('addr-1') }
end

# ---- tokens -----------------------------------------------------------
class FabricTokensCoverageMockTest < Minitest::Test
  include FabricCoverageHelpers

  def test_create_subscriber_token_success
    assert_kind_of Hash, @client.fabric.tokens.create_subscriber_token(reference: 'r')
    last = assert_request('POST', "#{FABRIC_BASE}/subscribers/tokens", 'fabric.create_subscriber_token')
    assert_equal 'r', last.body['reference']
  end

  def test_create_subscriber_token_error
    assert_error('fabric.create_subscriber_token', status: 422) do
      @client.fabric.tokens.create_subscriber_token(reference: 'r')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_refresh_subscriber_token_success
    assert_kind_of Hash, @client.fabric.tokens.refresh_subscriber_token(refresh_token: 'rt')
    last = assert_request('POST', "#{FABRIC_BASE}/subscribers/tokens/refresh", 'fabric.refresh_subscriber_token')
    assert_equal 'rt', last.body['refresh_token']
  end

  def test_refresh_subscriber_token_error
    assert_error('fabric.refresh_subscriber_token', status: 422) do
      @client.fabric.tokens.refresh_subscriber_token(refresh_token: 'rt')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_create_invite_token_success
    assert_kind_of Hash, @client.fabric.tokens.create_invite_token(email: 'i@e.com')
    last = assert_request('POST', "#{FABRIC_BASE}/subscriber/invites", 'fabric.create_subscriber_invite_token')
    assert_equal 'i@e.com', last.body['email']
  end

  def test_create_invite_token_error
    assert_error('fabric.create_subscriber_invite_token', status: 422) do
      @client.fabric.tokens.create_invite_token(email: 'i@e.com')
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_create_guest_token_success
    assert_kind_of Hash, @client.fabric.tokens.create_guest_token(allowed_addresses: %w[a-1])
    last = assert_request('POST', "#{FABRIC_BASE}/guests/tokens", 'fabric.create_subscriber_guest_token')
    assert_equal %w[a-1], last.body['allowed_addresses']
  end

  def test_create_guest_token_error
    assert_error('fabric.create_subscriber_guest_token', status: 422) do
      @client.fabric.tokens.create_guest_token(allowed_addresses: %w[a-1])
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end

  def test_create_embed_token_success
    assert_kind_of Hash, @client.fabric.tokens.create_embed_token(allowed_addresses: %w[a-1 a-2])
    last = assert_request('POST', "#{FABRIC_BASE}/embeds/tokens", 'fabric.create_embeds_token')
    assert_equal %w[a-1 a-2], last.body['allowed_addresses']
  end

  def test_create_embed_token_error
    assert_error('fabric.create_embeds_token', status: 422) do
      @client.fabric.tokens.create_embed_token(allowed_addresses: %w[a-1 a-2])
    end
    refute_nil @mock.last.response_status, 'error not journaled'
  end
end
