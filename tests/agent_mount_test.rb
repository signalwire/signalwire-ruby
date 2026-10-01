# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/mock'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# AgentBase#mount serves an extra Rack app alongside the agent's own routes.
# Parity: signalwire-python core/mixins/web_mixin.py:267 WebMixin.mount.
class AgentMountTest < Minitest::Test
  STATIC = ->(env) { [200, { 'content-type' => 'text/plain' }, ["mounted:#{env['PATH_INFO']}"]] }

  def agent
    SignalWire::AgentBase.new(name: 'demo', route: '/agent', basic_auth: %w[u p])
  end

  def test_mounted_app_is_served_at_its_prefix
    a = agent.mount(STATIC, prefix: '/chat/')
    res = Rack::MockRequest.new(a.rack_app).get('/chat/hello')

    assert_equal 200, res.status
    assert_equal 'mounted:/hello', res.body
  end

  def test_agent_routes_keep_working_and_keep_their_auth
    a = agent.mount(STATIC, prefix: '/demo')
    app = Rack::MockRequest.new(a.rack_app)

    assert_equal 401, app.get('/agent').status
    assert_equal 200, app.get('/health').status
  end

  def test_mount_after_the_app_was_built_rebuilds_it
    a = agent
    a.rack_app
    a.mount(STATIC, prefix: '/late')

    assert_equal 'mounted:/x', Rack::MockRequest.new(a.rack_app).get('/late/x').body
  end

  def test_returns_self_and_requires_a_rack_app
    a = agent

    assert_same a, a.mount(STATIC, prefix: '/s', name: 'static')
    assert_raises(ArgumentError) { a.mount(Object.new, prefix: '/x') }
  end
end
