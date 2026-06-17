# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/rest/rest_client'

# Mock HttpClient that records requests without hitting the network.
class RecordingHttpClient
  attr_reader :requests

  def initialize
    @requests = []
  end

  def get(path, params = nil)
    @requests << { method: 'GET', path: path, body: nil, params: params }
    {}
  end

  def post(path, body = nil, params: nil)
    @requests << { method: 'POST', path: path, body: body, params: params }
    {}
  end

  def put(path, body = nil)
    @requests << { method: 'PUT', path: path, body: body, params: nil }
    {}
  end

  def patch(path, body = nil)
    @requests << { method: 'PATCH', path: path, body: body, params: nil }
    {}
  end

  def delete(path)
    @requests << { method: 'DELETE', path: path, body: nil, params: nil }
    {}
  end

  def last
    @requests.last
  end
end

class RestPhoneNumbersBindingTest < Minitest::Test
  BASE = '/api/relay/rest/phone_numbers'

  def setup
    @http = RecordingHttpClient.new
    @phone_numbers = SignalWire::REST::Namespaces::PhoneNumbersResource.new(@http)
  end

  # --- CRUD baseline ---------------------------------------------------

  def test_update_uses_put
    @phone_numbers.update('pn-1', name: 'Main')

    assert_equal 'PUT', @http.last[:method]
    assert_equal "#{BASE}/pn-1", @http.last[:path]
    assert_equal({ name: 'Main' }, @http.last[:body])
  end

  def test_search_builds_query_path
    @phone_numbers.search(area_code: '512')

    assert_equal 'GET', @http.last[:method]
    assert_equal "#{BASE}/search", @http.last[:path]
    assert_equal({ area_code: '512' }, @http.last[:params])
  end

  # --- PhoneCallHandler enum contract ----------------------------------

  def test_phone_call_handler_has_all_11_wire_values
    expected = %w[
      relay_script laml_webhooks laml_application ai_agent call_flow
      relay_application relay_topic relay_context relay_connector
      video_room dialogflow
    ].freeze

    assert_equal expected.sort, SignalWire::REST::PhoneCallHandler::ALL.sort
  end

  def test_phone_call_handler_constants_match_wire_values
    assert_equal 'relay_script',      SignalWire::REST::PhoneCallHandler::RELAY_SCRIPT
    assert_equal 'laml_webhooks',     SignalWire::REST::PhoneCallHandler::LAML_WEBHOOKS
    assert_equal 'laml_application',  SignalWire::REST::PhoneCallHandler::LAML_APPLICATION
    assert_equal 'ai_agent',          SignalWire::REST::PhoneCallHandler::AI_AGENT
    assert_equal 'call_flow',         SignalWire::REST::PhoneCallHandler::CALL_FLOW
    assert_equal 'relay_application', SignalWire::REST::PhoneCallHandler::RELAY_APPLICATION
    assert_equal 'relay_topic',       SignalWire::REST::PhoneCallHandler::RELAY_TOPIC
    assert_equal 'relay_context',     SignalWire::REST::PhoneCallHandler::RELAY_CONTEXT
    assert_equal 'relay_connector',   SignalWire::REST::PhoneCallHandler::RELAY_CONNECTOR
    assert_equal 'video_room',        SignalWire::REST::PhoneCallHandler::VIDEO_ROOM
    assert_equal 'dialogflow',        SignalWire::REST::PhoneCallHandler::DIALOGFLOW
  end

  def test_phone_call_handler_all_frozen
    assert_predicate SignalWire::REST::PhoneCallHandler::ALL, :frozen?
  end

  # --- set_swml_webhook ------------------------------------------------

  def test_set_swml_webhook_wire_body
    @phone_numbers.set_swml_webhook('pn-1', url: 'https://example.com/swml')

    assert_equal 'PUT', @http.last[:method]
    assert_equal "#{BASE}/pn-1", @http.last[:path]
    assert_equal(
      { call_handler: 'relay_script', call_relay_script_url: 'https://example.com/swml' },
      @http.last[:body]
    )
  end

  def test_set_swml_webhook_extra_kwargs_pass_through
    @phone_numbers.set_swml_webhook('pn-1', url: 'https://example.com/swml', name: 'Support')
    body = @http.last[:body]

    assert_equal 'Support', body[:name]
    assert_equal 'relay_script', body[:call_handler]
    assert_equal 'https://example.com/swml', body[:call_relay_script_url]
  end

  # --- set_cxml_webhook ------------------------------------------------

  def test_set_cxml_webhook_minimal
    @phone_numbers.set_cxml_webhook('pn-1', url: 'https://example.com/voice.xml')

    assert_equal(
      { call_handler: 'laml_webhooks', call_request_url: 'https://example.com/voice.xml' },
      @http.last[:body]
    )
  end

  def test_set_cxml_webhook_with_fallback_and_status
    @phone_numbers.set_cxml_webhook(
      'pn-1',
      url: 'https://example.com/voice.xml',
      fallback_url: 'https://example.com/fallback.xml',
      status_callback_url: 'https://example.com/status'
    )

    assert_equal(
      {
        call_handler: 'laml_webhooks',
        call_request_url: 'https://example.com/voice.xml',
        call_fallback_url: 'https://example.com/fallback.xml',
        call_status_callback_url: 'https://example.com/status'
      },
      @http.last[:body]
    )
  end

  # --- set_cxml_application --------------------------------------------

  def test_set_cxml_application_wire_body
    @phone_numbers.set_cxml_application('pn-1', application_id: 'app-1')

    assert_equal(
      { call_handler: 'laml_application', call_laml_application_id: 'app-1' },
      @http.last[:body]
    )
  end

  # --- set_ai_agent ----------------------------------------------------

  def test_set_ai_agent_wire_body
    @phone_numbers.set_ai_agent('pn-1', agent_id: 'agent-1')

    assert_equal(
      { call_handler: 'ai_agent', call_ai_agent_id: 'agent-1' },
      @http.last[:body]
    )
  end

  # --- set_call_flow ---------------------------------------------------

  def test_set_call_flow_minimal
    @phone_numbers.set_call_flow('pn-1', flow_id: 'cf-1')

    assert_equal(
      { call_handler: 'call_flow', call_flow_id: 'cf-1' },
      @http.last[:body]
    )
  end

  def test_set_call_flow_with_version
    @phone_numbers.set_call_flow('pn-1', flow_id: 'cf-1', version: 'current_deployed')

    assert_equal(
      {
        call_handler: 'call_flow',
        call_flow_id: 'cf-1',
        call_flow_version: 'current_deployed'
      },
      @http.last[:body]
    )
  end

  # --- set_relay_application -------------------------------------------

  def test_set_relay_application_wire_body
    @phone_numbers.set_relay_application('pn-1', name: 'my-app')

    assert_equal(
      { call_handler: 'relay_application', call_relay_application: 'my-app' },
      @http.last[:body]
    )
  end

  # --- set_relay_topic -------------------------------------------------

  def test_set_relay_topic_minimal
    @phone_numbers.set_relay_topic('pn-1', topic: 'office')

    assert_equal(
      { call_handler: 'relay_topic', call_relay_topic: 'office' },
      @http.last[:body]
    )
  end

  def test_set_relay_topic_with_status_callback
    @phone_numbers.set_relay_topic(
      'pn-1',
      topic: 'office',
      status_callback_url: 'https://example.com/status'
    )

    assert_equal(
      {
        call_handler: 'relay_topic',
        call_relay_topic: 'office',
        call_relay_topic_status_callback_url: 'https://example.com/status'
      },
      @http.last[:body]
    )
  end

  # --- Helper coverage -------------------------------------------------

  def test_all_seven_typed_helpers_present
    %i[
      set_swml_webhook set_cxml_webhook set_cxml_application set_ai_agent
      set_call_flow set_relay_application set_relay_topic
    ].each do |name|
      assert_respond_to @phone_numbers, name, "phone_numbers missing binding helper: #{name}"
    end
  end

  # --- Post-mortem regression ------------------------------------------

  # The phone-binding post-mortem identified two traps that cost a user hours:
  #   1. fabric.swml_webhooks.create(...) -> produces an orphan resource.
  #   2. fabric.resources.assign_phone_route(...) -> returns 404/422 for
  #      swml_webhook / cxml_webhook / ai_agent.
  # The correct path is entirely through phone_numbers.update (directly or via
  # the typed helpers). This test pins that contract.
  def test_swml_binding_is_single_put_to_phone_numbers
    @phone_numbers.set_swml_webhook('pn-1', url: 'https://example.com/swml')

    assert_equal 1, @http.requests.size, 'should make exactly one HTTP call'
    req = @http.requests.first

    assert_equal 'PUT', req[:method]
    assert_equal "#{BASE}/pn-1", req[:path]
    refute_includes req[:path], '/api/fabric/resources/swml_webhooks',
                    'should not call fabric.swml_webhooks.create'
    refute_includes req[:path], '/phone_routes',
                    'should not call assign_phone_route'
  end

  def test_wire_level_form_works_without_enum
    @phone_numbers.update(
      'pn-1',
      call_handler: 'relay_script',
      call_relay_script_url: 'https://example.com/swml'
    )
    body = @http.last[:body]

    assert_equal 'relay_script', body[:call_handler]
    assert_equal 'https://example.com/swml', body[:call_relay_script_url]
  end

  def test_enum_constant_and_wire_string_serialize_identically
    @phone_numbers.update(
      'pn-1',
      call_handler: SignalWire::REST::PhoneCallHandler::RELAY_SCRIPT,
      call_relay_script_url: 'https://example.com/swml'
    )

    assert_equal 'relay_script', @http.last[:body][:call_handler]
  end
end
