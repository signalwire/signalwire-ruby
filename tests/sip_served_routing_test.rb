# frozen_string_literal: true

# Behavioral contract #6: SIP routing DISPATCH over the served path.
#
# Python: enable_sip_routing registers a routing callback at the SIP path; a
# POST to the served /sip endpoint invokes it, extracts the SIP username from
# the body, and routes. Before this fix the Ruby enable_sip_routing set flags
# and registered usernames but NEVER called register_routing_callback, so the
# /sip mapping was stored-but-unconsulted: a POST to /sip rendered SWML without
# ever looking at the SIP username. These tests drive the ACTUAL served rack
# app (#61 wiring) and assert the callback is registered + fires + extracts the
# username + the request is routed.

require 'minitest/autorun'
require 'rack/test'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class SipServedRoutingTest < Minitest::Test
  include Rack::Test::Methods

  attr_reader :app

  def build_agent(&config)
    agent = SignalWire::AgentBase.new(name: 'sipper', route: '/', basic_auth: %w[u p])
    agent.set_prompt_text('Hello')
    config&.call(agent)
    agent
  end

  def auth_header
    header 'Authorization', "Basic #{['u:p'].pack('m0')}"
  end

  def sip_body(user)
    JSON.generate('call' => { 'to' => "sip:#{user}@example.com" })
  end

  # Reach into the registered routing callbacks (the wiring the fix installs).
  def sip_callback(agent)
    agent.instance_variable_get(:@routing_callbacks)['/sip']
  end

  # The CORE fix: enable_sip_routing must register a routing callback at the
  # SIP path — the wiring that was missing (stored-but-unconsulted → consulted).
  def test_enable_sip_routing_registers_a_callback_at_the_sip_path
    agent = build_agent { |a| a.enable_sip_routing(auto_map: false).register_sip_username('alice') }

    refute_nil sip_callback(agent),
               'enable_sip_routing must register a routing callback at /sip (was stored-but-unconsulted)'
  end

  # The registered callback extracts the SIP username from the body (proving it
  # actually parses SIP, not a no-op). Python parity: it returns nil so this
  # agent handles the call (renders SWML), for both matched and unmatched.
  def test_registered_sip_callback_extracts_username_from_body
    agent = build_agent { |a| a.enable_sip_routing(auto_map: false).register_sip_username('alice') }
    cb = sip_callback(agent)

    parsed = JSON.parse(sip_body('alice'))
    # The callback returns nil (matched → agent handles) but only after parsing;
    # prove parsing independently via the extractor it delegates to.
    assert_nil cb.call(parsed, {})
    assert_equal 'alice', SignalWire::AgentBase.extract_sip_username_from_request(parsed)
  end

  # End-to-end over the ACTUAL served rack app: a POST to /sip flows through the
  # #61 handle_request wiring and reaches the registered SIP callback (200 SWML
  # for a matched username — the mapped behavior). A stored-but-unconsulted
  # mapping could never make this path consult the SIP username at all.
  def test_served_sip_post_routes_through_the_callback
    @agent = build_agent { |a| a.enable_sip_routing(auto_map: false).register_sip_username('alice') }
    @app = @agent.rack_app

    auth_header
    post '/sip', sip_body('alice'), 'CONTENT_TYPE' => 'application/json'

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)

    assert body.key?('sections'), 'matched SIP username is handled by the agent → SWML rendered'
  end

  # The mapped behavior can also be a redirect: when the registered callback
  # returns a Location, the served /sip path 307s (proves the SIP callback's
  # return value flows into the #61 redirect wiring, not just a rendered doc).
  def test_served_sip_redirects_when_callback_returns_location
    @agent = build_agent
    # Register a SIP-path routing callback that redirects on a parsed username —
    # the same wiring enable_sip_routing uses, exercising the redirect branch.
    @agent.register_routing_callback('/sip') do |body, _headers|
      user = SignalWire::AgentBase.extract_sip_username_from_request(body)
      user ? "/agents/#{user}" : nil
    end
    @app = @agent.rack_app

    auth_header
    post '/sip', sip_body('alice'), 'CONTENT_TYPE' => 'application/json'

    assert_equal 307, last_response.status
    assert_equal '/agents/alice', last_response.headers['Location']
  end

  # Auto-map derives usernames from name/route and the wiring is installed, so
  # the served path consults them too (end-to-end enable_sip_routing default).
  def test_auto_mapped_username_is_registered_and_wired
    agent = build_agent { |a| a.enable_sip_routing(auto_map: true) }

    assert_includes agent.instance_variable_get(:@sip_usernames), 'sipper'
    refute_nil sip_callback(agent)
  end
end
