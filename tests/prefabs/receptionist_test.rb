# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/prefabs/receptionist'

class ReceptionistPrefabDetailedTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [
        { 'name' => 'sales', 'description' => 'Sales dept', 'number' => '+15551235555' }
      ]
    )
    assert_equal 'receptionist', agent.name
    assert_equal 1, agent.departments.size
  end

  def test_tools
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [{ 'name' => 'sales', 'description' => 'Sales', 'number' => '+15551235555' }]
    )
    assert_includes agent.tools, 'transfer_to_department'
    assert_includes agent.tools, 'collect_caller_info'
  end

  def test_handle_transfer
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [{ 'name' => 'sales', 'description' => 'Sales', 'number' => '+15551235555' }]
    )
    result = agent.handle_transfer({ 'department' => 'sales' }, {})
    assert_match(/transferring/i, result.response)
  end

  def test_handle_transfer_unknown_department
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [{ 'name' => 'sales', 'description' => 'Sales', 'number' => '+15551235555' }]
    )
    result = agent.handle_transfer({ 'department' => 'unknown' }, {})
    assert_includes result.response, 'sales'
  end

  def test_raises_without_departments
    assert_raises(ArgumentError) { SignalWire::Prefabs::Receptionist.new(departments: []) }
  end

  def test_global_data
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [{ 'name' => 'sales', 'description' => 'Sales', 'number' => '+15551235555' }]
    )
    data = agent.global_data
    assert data.key?('departments')
    assert_equal 1, data['departments'].size
  end
end
