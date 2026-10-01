# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# AgentBase#on_call_end wraps the reserved hangup_hook and turns on
# swaig_post_conversation (without which the hook carries no call_log).
# Parity: signalwire-python core/agent_base.py:663 AgentBase.on_call_end.
class AgentOnCallEndTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new(name: 'demo', route: '/demo')
  end

  def ai(agent = @agent)
    agent.render_swml['sections']['main'].find { |v| v.key?('ai') }['ai']
  end

  def test_registers_the_hangup_hook_and_enables_post_conversation
    @agent.on_call_end(nil) { |_log, _raw| nil }
    hook = ai['SWAIG']['functions'].find { |f| f['function'] == 'hangup_hook' }

    assert_equal 'Internal: fires when the call ends.', hook['description']
    assert(ai['params']['swaig_post_conversation'])
  end

  def test_explicit_false_is_left_alone
    @agent.set_param('swaig_post_conversation', false)
    @agent.on_call_end(nil) { |_log, _raw| nil }

    refute ai['params']['swaig_post_conversation']
  end

  def test_handlers_run_in_order_with_the_call_log_from_either_spelling
    seen = []
    @agent.on_call_end(nil) { |log, raw| seen << [:first, log, raw['call_id']] }
    @agent.on_call_end(nil) { |log, _raw| seen << [:second, log] }
    @agent.on_function_call('hangup_hook', {}, { 'call_id' => 'c1', 'raw_call_log' => [{ 'role' => 'user' }] })

    assert_equal [[:first, [{ 'role' => 'user' }], 'c1'], [:second, [{ 'role' => 'user' }]]], seen
  end

  def test_a_failing_handler_does_not_stop_the_others
    ran = []
    @agent.on_call_end(nil) { |_log, _raw| raise 'boom' }
    @agent.on_call_end(nil) { |log, _raw| ran << log }
    @agent.on_function_call('hangup_hook', {}, { 'call_log' => [{ 'role' => 'assistant' }] })

    assert_equal [[{ 'role' => 'assistant' }]], ran
  end

  def test_returns_the_handler_and_needs_one
    handler = ->(_log, _raw) {}

    assert_same handler, @agent.on_call_end(handler)
    assert_raises(ArgumentError) { @agent.on_call_end(nil) }
  end
end
