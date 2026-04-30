# frozen_string_literal: true

require 'minitest/autorun'

# Suppress logging during tests
ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Parity with signalwire-python:
#   tests/unit/core/test_agent_base.py::TestAgentBaseTokenMethods#test_validate_tool_token
#   tests/unit/core/test_agent_base.py::TestAgentBaseTokenMethods#test_create_tool_token
#
# Python's StateMixin#_create_tool_token rescues all exceptions and returns ""
# on failure. validate_tool_token rejects unknown function names up front.
class ToolTokenTest < Minitest::Test
  def make_agent_with_tool(secure: true)
    agent = SignalWire::AgentBase.new(name: 'test_agent')
    agent.define_tool(
      name: 'test_tool',
      description: 't',
      parameters: {},
      secure: secure,
    ) { |_args, _raw| { 'response' => 'ok' } }
    agent
  end

  def test_create_tool_token_round_trip
    agent = make_agent_with_tool
    token = agent.create_tool_token('test_tool', 'call_123')
    refute_equal '', token, 'expected SessionManager-issued token, got empty'
    assert agent.validate_tool_token('test_tool', token, 'call_123'),
           'validate_tool_token rejected the token we just created'
  end

  def test_validate_tool_token_rejects_unknown_function
    agent = SignalWire::AgentBase.new(name: 'test_agent')
    refute agent.validate_tool_token('not_registered', 'any_token', 'call_123'),
           'expected false for unregistered function'
  end

  def test_validate_tool_token_rejects_bad_token
    agent = make_agent_with_tool
    refute agent.validate_tool_token('test_tool', 'garbage_token_value', 'call_123'),
           'expected false for garbage token'
  end

  def test_validate_tool_token_rejects_wrong_call_id
    agent = make_agent_with_tool
    token = agent.create_tool_token('test_tool', 'call_A')
    refute_equal '', token
    refute agent.validate_tool_token('test_tool', token, 'call_B'),
           'expected false when token bound to different call_id'
  end
end
