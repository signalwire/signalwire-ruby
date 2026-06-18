# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require_relative '../../lib/signalwire/rest/rest_client'
require_relative 'phone_numbers_test' # for RecordingHttpClient

class RestFabricDetailedTest < Minitest::Test
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

  def test_cxml_applications_create_raises
    http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
    resource = SignalWire::REST::Namespaces::CxmlApplicationsResource.new(
      http, '/api/fabric/resources/cxml_applications'
    )
    assert_raises(NotImplementedError) { resource.create(name: 'test') }
  end

  # --- Deprecation warnings --------------------------------------------
  # The three code paths identified in the phone-binding post-mortem that
  # users reached for but that don't bind a phone number must warn loudly.

  def test_assign_phone_route_emits_deprecation_warning
    http = RecordingHttpClient.new
    resources = SignalWire::REST::Namespaces::GenericResources.new(
      http, '/api/fabric/resources'
    )
    stderr = capture_warn { resources.assign_phone_route('r-1', phone_number: '+15551234567') }

    assert_match(/DEPRECATION/, stderr)
    assert_match(/phone_numbers\.set_swml_webhook/, stderr)
    # But the method still works -- call actually went through.
    assert_equal 'POST', http.last[:method]
    assert_equal '/api/fabric/resources/r-1/phone_routes', http.last[:path]
  end

  def test_swml_webhooks_create_emits_deprecation_warning
    http = RecordingHttpClient.new
    webhook = SignalWire::REST::Namespaces::SwmlWebhooksResource.new(http, '/api/fabric/resources/swml_webhooks')
    stderr = capture_warn { webhook.create(name: 'x', primary_request_url: 'https://example.com/swml') }

    assert_match(/DEPRECATION/, stderr)
    assert_match(/phone_numbers\.set_swml_webhook/, stderr)
    # Still works.
    assert_equal 'POST', http.last[:method]
    assert_equal '/api/fabric/resources/swml_webhooks', http.last[:path]
  end

  def test_cxml_webhooks_create_emits_deprecation_warning
    http = RecordingHttpClient.new
    webhook = SignalWire::REST::Namespaces::CxmlWebhooksResource.new(http, '/api/fabric/resources/cxml_webhooks')
    stderr = capture_warn { webhook.create(name: 'x', primary_request_url: 'https://example.com/cxml') }

    assert_match(/DEPRECATION/, stderr)
    assert_match(/phone_numbers\.set_cxml_webhook/, stderr)
    assert_equal 'POST', http.last[:method]
    assert_equal '/api/fabric/resources/cxml_webhooks', http.last[:path]
  end

  # List/get/update/delete on SwmlWebhooksResource should NOT warn -- only
  # create is deprecated.
  def test_swml_webhooks_list_does_not_warn
    http = RecordingHttpClient.new
    webhook = SignalWire::REST::Namespaces::SwmlWebhooksResource.new(
      http, '/api/fabric/resources/swml_webhooks'
    )
    stderr = capture_warn { webhook.list }

    assert_equal '', stderr
  end

  def test_swml_webhooks_delete_does_not_warn
    http = RecordingHttpClient.new
    webhook = SignalWire::REST::Namespaces::SwmlWebhooksResource.new(
      http, '/api/fabric/resources/swml_webhooks'
    )
    stderr = capture_warn { webhook.delete('r-1') }

    assert_equal '', stderr
  end

  private

  def capture_warn
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end
end
