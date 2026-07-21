# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/rest/rest_client'

class RestNamespacesDetailedTest < Minitest::Test
  # The REST resource classes are now GENERATED (scripts/generate_rest.py) and
  # live under SignalWire::REST::Namespaces::Generated::*, each with a base path
  # baked into its one-arg (http) constructor.
  Gen = SignalWire::REST::Namespaces::Generated

  def setup
    @http = SignalWire::REST::HttpClient.new('proj', 'tok', 'test.signalwire.com')
  end

  ALL_NAMESPACES = %i[
    fabric calling phone_numbers datasphere video addresses queues
    recordings number_groups verified_callers sip_profile lookup short_codes
    imported_numbers mfa registry logs project pubsub chat
  ].freeze

  def test_all_20_namespaces_non_nil
    client = SignalWire::REST::RestClient.new(
      project: 'proj', token: 'tok', host: 'test.signalwire.com'
    )

    ALL_NAMESPACES.each { |ns| refute_nil client.public_send(ns), "#{ns} namespace must not be nil" }
  end

  def test_phone_numbers_path
    resource = Gen::PhoneNumbers.new(@http)

    assert_equal '/api/relay/rest/phone_numbers/search', resource.send(:_path, 'search')
  end

  def test_addresses_path
    resource = Gen::Addresses.new(@http)

    assert_equal '/api/relay/rest/addresses/abc', resource.send(:_path, 'abc')
  end

  def test_queues_path
    resource = Gen::Queues.new(@http)

    assert_equal '/api/relay/rest/queues/q1/members', resource.send(:_path, 'q1', 'members')
  end

  def test_mfa_path
    resource = Gen::Mfa.new(@http)

    assert_equal '/api/relay/rest/mfa/sms', resource.send(:_path, 'sms')
  end

  def test_lookup_path
    resource = Gen::Lookup.new(@http)

    assert_equal '/api/relay/rest/lookup/phone_number/+15551234567',
                 resource.send(:_path, 'phone_number', '+15551234567')
  end

  def test_sip_profile_path
    resource = Gen::SipProfile.new(@http)

    assert_equal '/api/relay/rest/sip_profile', resource.instance_variable_get(:@base_path)
  end

  def test_pubsub_path
    resource = Gen::PubSub.new(@http)

    assert_equal '/api/pubsub/tokens', resource.instance_variable_get(:@base_path)
  end

  def test_chat_path
    resource = Gen::Chat.new(@http)

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

  def test_crud_resource_default_update_method
    assert_equal 'PATCH', SignalWire::REST::CrudResource.update_method
  end

  # The generated phone_numbers resource issues item-level updates with PUT.
  # Unlike the old hand class (which set the CrudResource `update_method` class
  # attr to 'PUT'), the generated `update` bakes the PUT verb into its own method
  # body, so we assert the wire verb behaviorally via a recording HttpClient.
  def test_phone_numbers_update_uses_put
    recorder = PutRecordingHttp.new
    Gen::PhoneNumbers.new(recorder).update('pn-1', name: 'renamed')

    assert_equal [['PUT', '/api/relay/rest/phone_numbers/pn-1']], recorder.calls
  end

  # Records the (verb, path) of PUT requests without hitting the network.
  class PutRecordingHttp < SignalWire::REST::HttpClient
    attr_reader :calls

    def initialize
      super('p', 't', 'x.signalwire.com')
      @calls = []
    end

    def put(path, _body = nil, request_options: nil) # rubocop:disable Lint/UnusedMethodArgument
      @calls << ['PUT', path]
      {}
    end
  end
end
