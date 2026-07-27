# frozen_string_literal: true

# Regression guard for the RestClient resource-tree accessors.
#
# `RestClient` composes its 22 flat-resource / namespace-container accessors by
# including the GENERATED `Namespaces::Generated::ResourceTree` module
# (rest_client.rb:42) rather than defining them in the class body. A reflective
# walk that only looks at methods defined directly on `RestClient` misses all 22
# — which is exactly the enumerator blind spot this file pins shut from the
# behavioural side: every accessor named in the reference surface must be
# reachable on a live client, and requests reached through the accessor path must
# actually land on the wire.

require 'minitest/autorun'
require_relative 'mock_test'

class ResourceTreeAccessorsMockTest < Minitest::Test
  parallelize_me!

  RELAY_BASE = '/api/relay/rest'
  VIDEO_BASE = '/api/video'
  FABRIC_BASE = '/api/fabric/resources'

  # The full accessor set the reference (python) RestClient exposes. Hard-coded
  # rather than derived from ResourceTree so the test fails if an accessor is
  # ever dropped from the generated module.
  EXPECTED_ACCESSORS = %w[
    addresses calling chat datasphere fabric imported_numbers logs lookup
    messages mfa number_groups phone_numbers project projects pubsub queues
    recordings registry short_codes sip_profile verified_callers video
  ].freeze

  def setup
    h = MockTest.client
    @client = h[:client]
    @mock   = h[:mock]
  end

  # Every expected accessor answers on a live client and returns a real object.
  def test_every_resource_tree_accessor_is_reachable
    missing = EXPECTED_ACCESSORS.reject { |name| @client.respond_to?(name) }

    assert_empty missing, "RestClient is missing accessors: #{missing.join(', ')}"

    EXPECTED_ACCESSORS.each do |name|
      resource = @client.public_send(name)

      refute_nil resource, "client.#{name} returned nil"
    end
  end

  # The accessors memoize: a second call returns the very same object.
  def test_accessors_memoize
    EXPECTED_ACCESSORS.each do |name|
      assert_same @client.public_send(name), @client.public_send(name),
                  "client.#{name} is not memoized"
    end
  end

  # A flat resource reached through the accessor path lands a real request.
  def test_addresses_accessor_reaches_the_wire
    body = @client.addresses.list

    assert_kind_of Hash, body
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/addresses", last.path
    refute_nil last.matched_route
  end

  # A namespace container reached through the accessor path lands a real request.
  def test_fabric_accessor_reaches_the_wire
    body = @client.fabric.ai_agents.list

    assert_kind_of Hash, body
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{FABRIC_BASE}/ai_agents", last.path
    refute_nil last.matched_route
  end

  # A second namespace container, on a different spec namespace.
  def test_video_accessor_reaches_the_wire
    body = @client.video.rooms.list

    assert_kind_of Hash, body
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{VIDEO_BASE}/rooms", last.path
    refute_nil last.matched_route
  end
end
