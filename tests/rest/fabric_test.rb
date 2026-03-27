# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/rest/rest_client'

class RestFabricDetailedTest < Minitest::Test
  def test_fabric_sub_resources
    client = SignalWire::REST::RestClient.new(
      project: 'proj', token: 'tok', host: 'test.signalwire.com'
    )
    fabric = client.fabric
    refute_nil fabric.swml_scripts
    refute_nil fabric.relay_applications
    refute_nil fabric.call_flows
    refute_nil fabric.conference_rooms
    refute_nil fabric.freeswitch_connectors
    refute_nil fabric.subscribers
    refute_nil fabric.sip_endpoints
    refute_nil fabric.cxml_scripts
    refute_nil fabric.cxml_applications
    refute_nil fabric.swml_webhooks
    refute_nil fabric.ai_agents
    refute_nil fabric.sip_gateways
    refute_nil fabric.cxml_webhooks
    refute_nil fabric.resources
    refute_nil fabric.addresses
    refute_nil fabric.tokens
  end

  def test_cxml_applications_create_raises
    http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
    resource = SignalWire::REST::Namespaces::CxmlApplicationsResource.new(
      http, '/api/fabric/resources/cxml_applications'
    )
    assert_raises(NotImplementedError) { resource.create(name: 'test') }
  end
end
