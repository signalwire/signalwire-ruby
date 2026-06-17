# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/prefabs/concierge'

class ConciergePrefabDetailedTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Grand Hotel',
      services: ['room service', 'spa'],
      amenities: { 'pool' => { 'hours' => '7 AM - 10 PM' } }
    )

    assert_equal 'concierge', agent.name
    assert_equal 'Grand Hotel', agent.venue_name
    assert_equal 2, agent.services.size
  end

  def test_tools
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Test', services: ['test'], amenities: {}
    )

    assert_includes agent.tools, 'get_amenity_info'
    assert_includes agent.tools, 'get_service_info'
  end

  def test_handle_amenity_info_found
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel',
      services: [],
      amenities: { 'pool' => { 'hours' => '7-10' } }
    )
    result = agent.handle_amenity_info({ 'amenity' => 'pool' }, {})

    assert_includes result.response, '7-10'
  end

  def test_handle_amenity_info_not_found
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [],
      amenities: { 'pool' => 'Open daily' }
    )
    result = agent.handle_amenity_info({ 'amenity' => 'gym' }, {})

    assert_includes result.response, 'pool'
  end

  def test_handle_service_info_found
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel',
      services: ['room service'],
      amenities: {}
    )
    result = agent.handle_service_info({ 'service' => 'room' }, {})

    assert_includes result.response, 'room service'
  end

  def test_global_data
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: ['spa'], amenities: {}
    )
    data = agent.global_data

    assert_equal 'Hotel', data['venue_name']
    assert_includes data['services'], 'spa'
  end
end
