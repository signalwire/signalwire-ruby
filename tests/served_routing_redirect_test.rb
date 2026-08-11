# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Issue #61: the ACTUAL served path (serve / as_router -> rack_app) must route
# through the decomposed handle_request core so a routing-callback redirect
# returns a real 307 (Location) — not a 200 SWML render. Before the fix the
# Rack handler re-implemented auth+render but SKIPPED the routing-callback
# branch, so a POST to a routed path over the served app rendered SWML (200)
# instead of redirecting (307).
class ServedRoutingRedirectTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @agent = SignalWire::AgentBase.new(name: 'a', basic_auth: %w[u p])
    @agent.set_prompt_text('Hello')
    @agent.register_routing_callback(nil, '/sip') { |_body, _headers| '/redirected' }
    @agent.rack_app
  end

  def auth_header
    header 'Authorization', "Basic #{['u:p'].pack('m0')}"
  end

  # The core behavior fix: served POST to a routed path -> 307 + Location.
  def test_served_routing_callback_redirects
    auth_header
    post '/sip', JSON.generate('call_id' => 'x'), 'CONTENT_TYPE' => 'application/json'

    assert_equal 307, last_response.status,
                 'served routing callback must 307, not render SWML (200)'
    assert_equal '/redirected', last_response.headers['Location']
  end

  # Auth still enforced through the served path (via handle_request / middleware).
  def test_served_bad_auth_rejected
    header 'Authorization', "Basic #{['u:WRONG'].pack('m0')}"
    post '/sip', JSON.generate('call_id' => 'x'), 'CONTENT_TYPE' => 'application/json'

    assert_equal 401, last_response.status
  end

  # Happy path (no matching route) still renders SWML 200 through handle_request.
  def test_served_happy_path_renders_swml
    auth_header
    post '/', JSON.generate('call_id' => 'x'), 'CONTENT_TYPE' => 'application/json'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal '1.0.0', body['version']
    assert body['sections'].key?('main')
  end
end
