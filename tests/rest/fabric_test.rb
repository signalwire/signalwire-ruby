# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require_relative '../../lib/signalwire/rest/rest_client'
require_relative 'phone_numbers_test' # for RecordingHttpClient

class RestFabricDetailedTest < Minitest::Test
  # The fabric resources are now GENERATED (scripts/generate_rest.py) under
  # SignalWire::REST::Namespaces::Generated::*, each with a one-arg (http)
  # constructor (base path baked in).
  Gen = SignalWire::REST::Namespaces::Generated

  FABRIC_SUB_RESOURCES = %i[
    swml_scripts relay_applications call_flows conference_rooms freeswitch_connectors
    subscribers sip_endpoints cxml_scripts cxml_applications swml_webhooks ai_agents
    sip_gateways cxml_webhooks resources addresses tokens
  ].freeze

  def test_fabric_sub_resources
    client = SignalWire::REST::RestClient.new(project: 'proj', token: 'tok', host: 'test.signalwire.com')
    fabric = client.fabric

    FABRIC_SUB_RESOURCES.each { |name| refute_nil fabric.public_send(name), "fabric.#{name} is nil" }
  end

  # cXML applications have NO create route (mirrors python + typescript). The
  # generated CxmlApplications resource omits `create` entirely — so the class
  # simply does not respond to it (no raising scaffold), and nothing hits the
  # wire.
  def test_cxml_applications_has_no_create
    http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
    resource = Gen::CxmlApplications.new(http)

    refute_respond_to resource, :create
  end

  # swml_webhooks / cxml_webhooks are normally auto-materialized by
  # phone_numbers.set_*_webhook, but a direct create still works and POSTs to the
  # collection path.
  def test_swml_webhooks_create_posts_to_collection
    http = RecordingHttpClient.new
    Gen::SwmlWebhooks.new(http).create(primary_request_url: 'https://example.com/swml')

    assert_equal 'POST', http.last[:method]
    assert_equal '/api/fabric/resources/swml_webhooks', http.last[:path]
  end

  def test_cxml_webhooks_create_posts_to_collection
    http = RecordingHttpClient.new
    Gen::CxmlWebhooks.new(http).create(primary_request_url: 'https://example.com/cxml')

    assert_equal 'POST', http.last[:method]
    assert_equal '/api/fabric/resources/cxml_webhooks', http.last[:path]
  end

  # assign_phone_route on the generic-resources endpoint POSTs to
  # {id}/phone_routes.
  def test_assign_phone_route_posts_to_phone_routes
    http = RecordingHttpClient.new
    Gen::GenericResources.new(http).assign_phone_route('r-1', phone_route_id: 'pr-1', handler: 'relay_context')

    assert_equal 'POST', http.last[:method]
    assert_equal '/api/fabric/resources/r-1/phone_routes', http.last[:path]
  end

  # list/delete on the webhook resources hit their expected routes.
  def test_swml_webhooks_list_gets_collection
    http = RecordingHttpClient.new
    Gen::SwmlWebhooks.new(http).list

    assert_equal 'GET', http.last[:method]
    assert_equal '/api/fabric/resources/swml_webhooks', http.last[:path]
  end

  def test_swml_webhooks_delete_hits_item_path
    http = RecordingHttpClient.new
    Gen::SwmlWebhooks.new(http).delete('r-1')

    assert_equal 'DELETE', http.last[:method]
    assert_equal '/api/fabric/resources/swml_webhooks/r-1', http.last[:path]
  end
end
