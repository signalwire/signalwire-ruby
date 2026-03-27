# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/datetime'

class DateTimeSkillDetailedTest < Minitest::Test
  def setup
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    @skill = factory.call({})
    @skill.setup
  end

  def test_name_and_description
    assert_equal 'datetime', @skill.name
    assert_equal 'Get current date, time, and timezone information', @skill.description
  end

  def test_version
    assert_equal '1.0.0', @skill.version
  end

  def test_register_tools_returns_two_tools
    tools = @skill.register_tools
    assert_equal 2, tools.size
    names = tools.map { |t| t[:name] }
    assert_includes names, 'get_current_time'
    assert_includes names, 'get_current_date'
  end

  def test_get_current_time_handler
    tools = @skill.register_tools
    time_tool = tools.find { |t| t[:name] == 'get_current_time' }
    result = time_tool[:handler].call({ 'timezone' => 'UTC' }, {})
    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/current time is/i, result.response)
  end

  def test_get_current_date_handler
    tools = @skill.register_tools
    date_tool = tools.find { |t| t[:name] == 'get_current_date' }
    result = date_tool[:handler].call({ 'timezone' => 'UTC' }, {})
    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/date is/i, result.response)
  end

  def test_prompt_sections
    sections = @skill.get_prompt_sections
    assert_equal 1, sections.size
    assert_equal 'Date and Time Information', sections[0]['title']
  end

  def test_tool_parameters_include_timezone
    tools = @skill.register_tools
    tools.each do |t|
      assert t[:parameters].key?('timezone'), "#{t[:name]} should have timezone parameter"
    end
  end

  def test_setup_always_succeeds
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    skill = factory.call({})
    assert skill.setup
  end
end
