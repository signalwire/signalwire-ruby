# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# set_dynamic_config_callback holds ONE callback (a second call replaces it);
# add_per_call_config accumulates, running every callback in registration order
# against the same ephemeral agent.
# Parity: signalwire-python tests/unit/core/test_agent_consolidation.py TestPerCallConfig.
class AgentPerCallConfigTest < Minitest::Test
  def agent
    SignalWire::AgentBase.new(name: 'demo', route: '/demo')
  end

  def configure(agent, seen)
    agent.instance_variable_get(:@dynamic_config_callback).call({}, {}, {}, agent)
    seen
  end

  def test_added_callbacks_all_run_in_registration_order
    seen = []
    a = agent
    a.add_per_call_config(->(_q, _b, _h, _ag) { seen << 'first' })
    a.add_per_call_config(nil) { |_q, _b, _h, _ag| seen << 'second' }

    assert_equal %w[first second], configure(a, seen)
  end

  def test_set_still_replaces
    seen = []
    a = agent
    a.set_dynamic_config_callback(->(_q, _b, _h, _ag) { seen << 'one' })
    a.set_dynamic_config_callback(->(_q, _b, _h, _ag) { seen << 'two' })

    assert_equal %w[two], configure(a, seen)
  end

  def test_add_composes_with_a_previously_set_callback
    seen = []
    a = agent
    a.set_dynamic_config_callback(->(_q, _b, _h, _ag) { seen << 'set' })
    a.add_per_call_config(->(_q, _b, _h, _ag) { seen << 'added' })

    assert_equal %w[set added], configure(a, seen)
  end

  def test_a_fresh_agent_has_no_callback
    assert_nil agent.instance_variable_get(:@dynamic_config_callback)
  end

  def test_returns_self_and_needs_a_callback
    a = agent

    assert_same a, a.add_per_call_config(->(*) {})
    assert_raises(ArgumentError) { a.add_per_call_config(nil) }
  end

  def test_each_request_configures_its_own_ephemeral_copy
    a = agent
    a.add_per_call_config(->(_q, _b, _h, copy) { copy.set_param('temperature', 0.1) })
    a.add_per_call_config(->(_q, _b, _h, copy) { copy.set_param('top_p', 0.2) })
    copy = a.send(:apply_dynamic_config, {}, nil)
    params = copy.instance_variable_get(:@params)

    assert_equal [0.1, 0.2], params.values_at('temperature', 'top_p')
    refute a.instance_variable_get(:@params).key?('temperature')
  end
end
