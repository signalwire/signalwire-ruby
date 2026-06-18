# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/rest/rest_client'

class RestHttpClientTest < Minitest::Test
  def test_http_client_url_construction
    client = SignalWire::REST::HttpClient.new('proj-123', 'tok-abc', 'myspace.signalwire.com')

    assert_equal 'https://myspace.signalwire.com', client.base_url
  end

  def test_http_client_with_short_space
    client = SignalWire::REST::HttpClient.new('proj-123', 'tok-abc', 'myspace')

    assert_equal 'https://myspace.signalwire.com', client.base_url
  end
end

class RestSignalWireRestErrorTest < Minitest::Test
  def test_error_formatting
    err = SignalWire::REST::SignalWireRestError.new(404, 'Not Found', '/api/test', 'GET')

    assert_equal 404, err.status_code
    assert_equal 'Not Found', err.body
    assert_equal '/api/test', err.url
    assert_equal 'GET', err.method_name
    [/404/, %r{/api/test}, /GET/, /Not Found/].each { |re| assert_match(re, err.message) }
  end

  def test_error_default_method
    err = SignalWire::REST::SignalWireRestError.new(500, 'Error', '/api/fail')

    assert_equal 'GET', err.method_name
  end
end

class RestBaseResourceTest < Minitest::Test
  def test_base_resource_path_construction
    http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
    resource = SignalWire::REST::BaseResource.new(http, '/api/test')
    # Use send to test private method
    assert_equal '/api/test/abc/def', resource.send(:_path, 'abc', 'def')
    assert_equal '/api/test/123', resource.send(:_path, 123)
  end
end

class RestCrudResourceTest < Minitest::Test
  def test_crud_resource_default_update_method
    assert_equal 'PATCH', SignalWire::REST::CrudResource.update_method
  end

  def test_crud_resource_custom_update_method
    # PhoneNumbersResource uses PUT
    klass = SignalWire::REST::Namespaces::PhoneNumbersResource

    assert_equal 'PUT', klass.update_method
  end
end

class RestRestClientTest < Minitest::Test
  def test_client_creation_with_explicit_params
    client = SignalWire::REST::RestClient.new(
      project: 'proj-123',
      token: 'tok-abc',
      host: 'myspace.signalwire.com'
    )

    assert_instance_of SignalWire::REST::RestClient, client
  end

  def test_client_requires_all_params
    old_project = ENV.delete('SIGNALWIRE_PROJECT_ID')
    old_token = ENV.delete('SIGNALWIRE_API_TOKEN')
    old_space = ENV.delete('SIGNALWIRE_SPACE')

    assert_raises(ArgumentError) { SignalWire::REST::RestClient.new }
    assert_raises(ArgumentError) { SignalWire::REST::RestClient.new(project: 'proj', token: 'tok') }
  ensure
    ENV['SIGNALWIRE_PROJECT_ID'] = old_project if old_project
    ENV['SIGNALWIRE_API_TOKEN'] = old_token if old_token
    ENV['SIGNALWIRE_SPACE'] = old_space if old_space
  end

  def test_client_creation_from_env
    ENV['SIGNALWIRE_PROJECT_ID'] = 'env-proj'
    ENV['SIGNALWIRE_API_TOKEN'] = 'env-tok'
    ENV['SIGNALWIRE_SPACE'] = 'env-space.signalwire.com'

    assert_instance_of SignalWire::REST::RestClient, SignalWire::REST::RestClient.new
  ensure
    ENV.delete('SIGNALWIRE_PROJECT_ID')
    ENV.delete('SIGNALWIRE_API_TOKEN')
    ENV.delete('SIGNALWIRE_SPACE')
  end

  def test_all_21_namespaces_non_nil
    assert_accessors_present new_client,
                             %i[fabric calling phone_numbers datasphere video compat addresses
                                queues recordings number_groups verified_callers sip_profile lookup
                                short_codes imported_numbers mfa registry logs project pubsub chat]
  end

  def test_fabric_sub_resources
    assert_accessors_present new_client.fabric,
                             %i[swml_scripts relay_applications call_flows conference_rooms
                                freeswitch_connectors subscribers sip_endpoints cxml_scripts
                                cxml_applications swml_webhooks ai_agents sip_gateways cxml_webhooks
                                resources addresses tokens]
  end

  def test_video_sub_resources
    assert_accessors_present new_client.video,
                             %i[rooms room_tokens room_sessions room_recordings conferences
                                conference_tokens streams]
  end

  def test_compat_sub_resources
    assert_accessors_present new_client.compat,
                             %i[accounts calls messages faxes conferences phone_numbers applications
                                laml_bins queues recordings transcriptions tokens]
  end

  def test_registry_sub_resources
    assert_accessors_present new_client.registry, %i[brands campaigns orders numbers]
  end

  def test_logs_sub_resources
    assert_accessors_present new_client.logs, %i[messages voice fax conferences]
  end

  def test_datasphere_sub_resources
    assert_accessors_present new_client.datasphere, %i[documents]
  end

  def test_project_sub_resources
    assert_accessors_present new_client.project, %i[tokens]
  end

  private

  def new_client
    SignalWire::REST::RestClient.new(project: 'proj', token: 'tok', host: 'test.signalwire.com')
  end

  # Assert every named accessor on +obj+ returns a non-nil value.
  def assert_accessors_present(obj, accessors)
    accessors.each { |name| refute_nil obj.public_send(name), "#{name} should be present" }
  end
end

class RestNamespacePathsTest < Minitest::Test
  def setup
    @http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
  end

  def test_phone_numbers_path
    resource = SignalWire::REST::Namespaces::PhoneNumbersResource.new(@http)
    # Verify path construction via send
    assert_equal '/api/relay/rest/phone_numbers/search', resource.send(:_path, 'search')
  end

  def test_addresses_path
    resource = SignalWire::REST::Namespaces::AddressesResource.new(@http)

    assert_equal '/api/relay/rest/addresses/abc', resource.send(:_path, 'abc')
  end

  def test_queues_path
    resource = SignalWire::REST::Namespaces::QueuesResource.new(@http)

    assert_equal '/api/relay/rest/queues/q1/members', resource.send(:_path, 'q1', 'members')
  end

  def test_recordings_path
    resource = SignalWire::REST::Namespaces::RecordingsResource.new(@http)

    assert_equal '/api/relay/rest/recordings/r1', resource.send(:_path, 'r1')
  end

  def test_number_groups_path
    resource = SignalWire::REST::Namespaces::NumberGroupsResource.new(@http)

    assert_equal '/api/relay/rest/number_groups/g1/number_group_memberships',
                 resource.send(:_path, 'g1', 'number_group_memberships')
  end

  def test_verified_callers_path
    resource = SignalWire::REST::Namespaces::VerifiedCallersResource.new(@http)

    assert_equal '/api/relay/rest/verified_caller_ids/vc1/verification',
                 resource.send(:_path, 'vc1', 'verification')
  end

  def test_sip_profile_path
    resource = SignalWire::REST::Namespaces::SipProfileResource.new(@http)
    # Singleton resource, base path is the full path
    assert_equal '/api/relay/rest/sip_profile', resource.instance_variable_get(:@base_path)
  end

  def test_lookup_path
    resource = SignalWire::REST::Namespaces::LookupResource.new(@http)

    assert_equal '/api/relay/rest/lookup/phone_number/+15551234567',
                 resource.send(:_path, 'phone_number', '+15551234567')
  end

  def test_short_codes_path
    resource = SignalWire::REST::Namespaces::ShortCodesResource.new(@http)

    assert_equal '/api/relay/rest/short_codes/sc1', resource.send(:_path, 'sc1')
  end

  def test_imported_numbers_path
    resource = SignalWire::REST::Namespaces::ImportedNumbersResource.new(@http)

    assert_equal '/api/relay/rest/imported_phone_numbers',
                 resource.instance_variable_get(:@base_path)
  end

  def test_mfa_path
    resource = SignalWire::REST::Namespaces::MfaResource.new(@http)

    assert_equal '/api/relay/rest/mfa/sms', resource.send(:_path, 'sms')
    assert_equal '/api/relay/rest/mfa/req-1/verify', resource.send(:_path, 'req-1', 'verify')
  end

  def test_calling_path
    resource = SignalWire::REST::Namespaces::CallingNamespace.new(@http)

    assert_equal '/api/calling/calls', resource.instance_variable_get(:@base_path)
  end

  def test_pubsub_path
    resource = SignalWire::REST::Namespaces::PubSubResource.new(@http)

    assert_equal '/api/pubsub/tokens', resource.instance_variable_get(:@base_path)
  end

  def test_chat_path
    resource = SignalWire::REST::Namespaces::ChatResource.new(@http)

    assert_equal '/api/chat/tokens', resource.instance_variable_get(:@base_path)
  end
end

class RestCxmlApplicationsTest < Minitest::Test
  def test_cxml_applications_create_raises
    http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
    resource = SignalWire::REST::Namespaces::CxmlApplicationsResource.new(
      http, '/api/fabric/resources/cxml_applications'
    )
    assert_raises(NotImplementedError) do
      resource.create(name: 'test')
    end
  end
end
