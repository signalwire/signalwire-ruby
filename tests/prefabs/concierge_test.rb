# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/prefabs/concierge'

class ConciergePrefabDetailedTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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

  # ---- caller-supplied config is readable back AND reaches the prompt --------
  # The reference exposes hours_of_operation and special_instructions as public
  # attributes and renders both; this port stored them under private ivars and
  # never rendered special_instructions at all.

  def test_hours_of_operation_readable_back_as_a_map
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [], amenities: {},
      hours_of_operation: { 'weekdays' => '9-5', 'weekends' => '10-4' }
    )

    assert_equal({ 'weekdays' => '9-5', 'weekends' => '10-4' }, agent.hours_of_operation)
  end

  def test_hours_of_operation_defaults_when_absent
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [], amenities: {}
    )

    # The reference defaults to {"default": "9 AM - 5 PM"} rather than omitting
    # the section (prefabs/concierge.py:78).
    assert_equal({ 'default' => '9 AM - 5 PM' }, agent.hours_of_operation)
  end

  def test_per_label_hours_all_reach_the_rendered_prompt
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [], amenities: {},
      hours_of_operation: { 'weekdays' => '9-5', 'weekends' => '10-4' }
    )
    section = agent.prompt_sections.find { |s| s['title'] == 'Hours of Operation' }

    refute_nil section, 'Hours of Operation section must always be rendered'
    # Every label must be individually reachable — a single-string shape would
    # make per-label hours unrepresentable.
    assert_includes section['body'], 'Weekdays: 9-5'
    assert_includes section['body'], 'Weekends: 10-4'
  end

  def test_hours_section_rendered_even_with_no_caller_hours
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [], amenities: {}
    )
    section = agent.prompt_sections.find { |s| s['title'] == 'Hours of Operation' }

    refute_nil section
    assert_includes section['body'], '9 AM - 5 PM'
  end

  def test_special_instructions_readable_back_and_rendered
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [], amenities: {},
      special_instructions: ['Always offer valet parking.', 'Never quote prices.']
    )

    assert_equal ['Always offer valet parking.', 'Never quote prices.'],
                 agent.special_instructions

    section = agent.prompt_sections.find { |s| s['title'] == 'Instructions' }

    refute_nil section, 'special_instructions must reach the prompt, not just storage'
    assert_includes section['bullets'], 'Always offer valet parking.'
    assert_includes section['bullets'], 'Never quote prices.'
  end

  def test_special_instructions_default_empty_and_no_section
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [], amenities: {}
    )

    assert_empty agent.special_instructions
    assert_nil(agent.prompt_sections.find { |s| s['title'] == 'Instructions' })
  end

  def test_global_data_carries_hours_as_a_map_and_instructions
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Hotel', services: [], amenities: {},
      hours_of_operation: { 'daily' => '24/7' },
      special_instructions: ['Be brief.']
    )
    data = agent.global_data

    assert_equal({ 'daily' => '24/7' }, data['hours_of_operation'])
    assert_equal ['Be brief.'], data['special_instructions']
  end
end
