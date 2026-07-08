# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'base64'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require 'signalwire'

# Shared setup for the framework-free request-dispatch core:
#   SWMLService#handle_request(method, url, headers, body)
#     -> [status, headers, body_string]
# Mirrors python's decomposed handle_request / _handle_request_core: auth (401),
# routing-callback redirect (307), and the 200 SWML render — all over plain
# primitives instead of the Rack env.
class HandleRequestCoreTestBase < Minitest::Test
  def setup
    SignalWire::Logging.reset! if SignalWire::Logging.respond_to?(:reset!)
    ENV.delete('SWML_BASIC_AUTH_USER')
    ENV.delete('SWML_BASIC_AUTH_PASSWORD')
    ENV.delete('SWML_PROXY_URL_BASE')
    @svc = SignalWire::SWML::Service.new(name: 'svc', basic_auth: %w[u p])
  end

  def auth_headers
    { 'Authorization' => "Basic #{Base64.strict_encode64('u:p')}" }
  end
end

# 200 (authorized render), 401 (auth failure), and the on_request/proxy hooks.
class HandleRequestCoreServiceTest < HandleRequestCoreTestBase
  def test_get_renders_swml_document
    status, headers, body = @svc.handle_request('GET', 'http://host/', auth_headers)

    assert_equal 200, status
    assert_kind_of Hash, headers
    assert_kind_of Hash, JSON.parse(body)
    assert_equal @svc.render_document, body
  end

  def test_missing_auth_is_unauthorized
    status, headers, body = @svc.handle_request('GET', 'http://host/', {})

    assert_equal 401, status
    assert_equal 'Basic', headers['WWW-Authenticate']
    assert_equal 'Unauthorized', JSON.parse(body)['error']
  end

  def test_wrong_password_is_unauthorized
    bad = { 'Authorization' => "Basic #{Base64.strict_encode64('u:WRONG')}" }
    status, = @svc.handle_request('GET', 'http://host/', bad)

    assert_equal 401, status
  end

  def test_on_request_modifications_merged
    svc = SignalWire::SWML::Service.new(name: 'mod', basic_auth: %w[u p])
    svc.define_singleton_method(:on_request) { |_body, _cb| { 'version' => '9.9.9' } }
    status, _headers, body = svc.handle_request('GET', 'http://host/', auth_headers)
    doc = JSON.parse(body)

    assert_equal 200, status
    assert_equal '9.9.9', doc['version'] if doc.key?('version')
  end

  def test_proxy_detected_from_x_forwarded_headers
    headers = auth_headers.merge(
      'X-Forwarded-Host' => 'example.ngrok.io', 'X-Forwarded-Proto' => 'https'
    )
    @svc.handle_request('GET', 'http://internal/', headers)

    assert_equal 'https://example.ngrok.io', @svc.instance_variable_get(:@proxy_url_base)
  end
end

# The 307 routing-callback redirect and its (body, headers) parity.
class HandleRequestCoreRoutingTest < HandleRequestCoreTestBase
  def test_routing_callback_returns_redirect
    seen = {}
    @svc.register_routing_callback('/sip') { |body, headers| seen.merge!(body:, headers:) && '/redirected' }
    status, headers, body = @svc.handle_request('POST', 'http://host/sip', auth_headers, { 'call_id' => 'abc' })

    assert_equal 307, status
    assert_equal '/redirected', headers['Location']
    assert_equal '', body
    assert_equal({ 'call_id' => 'abc' }, seen[:body])
    assert_equal auth_headers, seen[:headers]
  end

  def test_routing_callback_returning_nil_falls_through
    @svc.register_routing_callback('/sip') { |_body, _headers| nil }
    status, = @svc.handle_request('POST', 'http://host/sip', auth_headers, { 'x' => 1 })

    assert_equal 200, status
  end

  def test_single_arg_routing_callback_still_supported
    got = nil
    @svc.register_routing_callback('/sip') do |body|
      got = body
      '/legacy'
    end
    status, headers, = @svc.handle_request('POST', 'http://host/sip', auth_headers, { 'y' => 2 })

    assert_equal 307, status
    assert_equal '/legacy', headers['Location']
    assert_equal({ 'y' => 2 }, got)
  end

  def test_get_does_not_trigger_routing_callback
    ran = false
    @svc.register_routing_callback('/sip') do |_body, _headers|
      ran = true
      '/nope'
    end
    status, = @svc.handle_request('GET', 'http://host/sip', auth_headers)

    assert_equal 200, status
    refute ran, 'routing callback must only run for a POST with a body'
  end
end

# The AgentBase override renders agent SWML via render_swml.
class HandleRequestCoreAgentTest < HandleRequestCoreTestBase
  def test_agent_base_renders_agent_swml
    agent = SignalWire::AgentBase.new(name: 'a', basic_auth: %w[u p])
    status, _headers, body = agent.handle_request('GET', 'http://host/', auth_headers)
    doc = JSON.parse(body)

    assert_equal 200, status
    assert(doc.key?('sections') || doc.key?('version'), 'agent SWML document rendered')
  end

  def test_agent_base_missing_auth_is_unauthorized
    agent = SignalWire::AgentBase.new(name: 'a', basic_auth: %w[u p])
    status, headers, = agent.handle_request('GET', 'http://host/', {})

    assert_equal 401, status
    assert_equal 'Basic', headers['WWW-Authenticate']
  end

  def test_agent_base_routing_redirect
    agent = SignalWire::AgentBase.new(name: 'a', basic_auth: %w[u p])
    agent.register_routing_callback('/sip') { |_body, _headers| '/elsewhere' }
    status, headers, = agent.handle_request(
      'POST', 'http://host/sip', auth_headers, { 'call_id' => 'z' }
    )

    assert_equal 307, status
    assert_equal '/elsewhere', headers['Location']
  end
end
