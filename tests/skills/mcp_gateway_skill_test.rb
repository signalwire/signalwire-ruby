# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/mcp_gateway'

class McpGatewaySkillDetailedTest < Minitest::Test
  def test_setup_requires_gateway_url
    factory = SignalWire::Skills::SkillRegistry.get_factory('mcp_gateway')
    skill = factory.call({})
    refute skill.setup
  end

  def test_setup_with_gateway_url
    factory = SignalWire::Skills::SkillRegistry.get_factory('mcp_gateway')
    skill = factory.call({ 'gateway_url' => 'https://mcp.example.com' })
    assert skill.setup
  end

  def test_register_tools_empty_by_default
    factory = SignalWire::Skills::SkillRegistry.get_factory('mcp_gateway')
    skill = factory.call({ 'gateway_url' => 'https://mcp.example.com' })
    skill.setup
    tools = skill.register_tools
    assert_equal 0, tools.size
  end

  def test_get_hints
    factory = SignalWire::Skills::SkillRegistry.get_factory('mcp_gateway')
    skill = factory.call({ 'gateway_url' => 'https://mcp.example.com' })
    skill.setup
    hints = skill.get_hints
    assert_includes hints, 'MCP'
    assert_includes hints, 'gateway'
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('mcp_gateway')
    skill = factory.call({ 'gateway_url' => 'https://mcp.example.com' })
    skill.setup
    data = skill.get_global_data
    assert_equal 'https://mcp.example.com', data['mcp_gateway_url']
  end
end
