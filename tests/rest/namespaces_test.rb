# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/rest/rest_client'

class RestNamespacesDetailedTest < Minitest::Test
  def setup
    @http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
  end

  ALL_NAMESPACES = %i[
    fabric calling phone_numbers datasphere video compat addresses queues
    recordings number_groups verified_callers sip_profile lookup short_codes
    imported_numbers mfa registry logs project pubsub chat
  ].freeze

  def test_all_21_namespaces_non_nil
    client = SignalWire::REST::RestClient.new(
      project: 'proj', token: 'tok', host: 'test.signalwire.com'
    )

    ALL_NAMESPACES.each { |ns| refute_nil client.public_send(ns), "#{ns} namespace must not be nil" }
  end

  def test_phone_numbers_path
    resource = SignalWire::REST::Namespaces::PhoneNumbersResource.new(@http)

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

  def test_mfa_path
    resource = SignalWire::REST::Namespaces::MfaResource.new(@http)

    assert_equal '/api/relay/rest/mfa/sms', resource.send(:_path, 'sms')
  end

  def test_lookup_path
    resource = SignalWire::REST::Namespaces::LookupResource.new(@http)

    assert_equal '/api/relay/rest/lookup/phone_number/+15551234567',
                 resource.send(:_path, 'phone_number', '+15551234567')
  end

  def test_sip_profile_path
    resource = SignalWire::REST::Namespaces::SipProfileResource.new(@http)

    assert_equal '/api/relay/rest/sip_profile', resource.instance_variable_get(:@base_path)
  end

  def test_pubsub_path
    resource = SignalWire::REST::Namespaces::PubSubResource.new(@http)

    assert_equal '/api/pubsub/tokens', resource.instance_variable_get(:@base_path)
  end

  def test_chat_path
    resource = SignalWire::REST::Namespaces::ChatResource.new(@http)

    assert_equal '/api/chat/tokens', resource.instance_variable_get(:@base_path)
  end

  def test_video_sub_resources
    client = SignalWire::REST::RestClient.new(
      project: 'proj', token: 'tok', host: 'test.signalwire.com'
    )
    video = client.video

    refute_nil video.rooms
    refute_nil video.room_tokens
    refute_nil video.room_sessions
    refute_nil video.conferences
    refute_nil video.streams
  end

  def test_compat_sub_resources
    client = SignalWire::REST::RestClient.new(
      project: 'proj', token: 'tok', host: 'test.signalwire.com'
    )
    compat = client.compat

    refute_nil compat.accounts
    refute_nil compat.calls
    refute_nil compat.messages
    refute_nil compat.faxes
  end

  def test_crud_resource_default_update_method
    assert_equal 'PATCH', SignalWire::REST::CrudResource.update_method
  end

  def test_phone_numbers_custom_update_method
    assert_equal 'PUT', SignalWire::REST::Namespaces::PhoneNumbersResource.update_method
  end
end
