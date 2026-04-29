# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'json'
require 'base64'
require 'signalwire'

# Tests proving SWML::Service can host SWAIG functions and serve a non-agent
# SWML doc (e.g. ai_sidecar) without subclassing AgentBase. This is the
# contract that lets sidecar / non-agent verbs reuse the SWAIG dispatch
# surface that previously lived only on AgentBase.
class SWMLServiceSwaigTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    SignalWire::Logging.reset!
    ENV.delete('SWML_BASIC_AUTH_USER')
    ENV.delete('SWML_BASIC_AUTH_PASSWORD')
    @svc = SignalWire::SWML::Service.new(
      name: 'svc', basic_auth: %w[u p]
    )
  end

  def app
    @svc.rack_app
  end

  def auth_header
    encoded = Base64.strict_encode64('u:p')
    { 'HTTP_AUTHORIZATION' => "Basic #{encoded}" }
  end

  # ----- Service gains SWAIG-hosting capability -----------------------

  def test_service_has_swaig_methods
    assert @svc.respond_to?(:define_tool)
    assert @svc.respond_to?(:register_swaig_function)
    assert @svc.respond_to?(:define_tools)
    assert @svc.respond_to?(:on_function_call)
  end

  def test_define_tool_registers_function_and_dispatches
    captured = {}
    @svc.define_tool(name: 'lookup', description: 'Look it up', parameters: {}) do |args, _raw|
      captured[:args] = args
      { 'response' => 'ok' }
    end
    result = @svc.on_function_call('lookup', { 'x' => 'y' }, {})
    assert_equal({ 'x' => 'y' }, captured[:args])
    assert_equal 'ok', result['response']
  end

  def test_on_function_call_returns_nil_for_unknown
    assert_nil @svc.on_function_call('no_such_fn', {}, {})
  end

  def test_list_tool_names_returns_registered_order
    @svc.define_tool(name: 'first', description: 'f', parameters: {}) { |_a, _r| { 'response' => '1' } }
    @svc.define_tool(name: 'second', description: 's', parameters: {}) { |_a, _r| { 'response' => '2' } }
    assert_equal %w[first second], @svc.list_tool_names
  end

  # ----- /swaig endpoint behavior -------------------------------------

  def test_swaig_get_returns_swml
    @svc.hangup
    get '/swaig', {}, auth_header
    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert body['sections']
  end

  def test_swaig_post_dispatches_registered_handler
    @svc.define_tool(
      name: 'lookup_competitor',
      description: 'Look up competitor pricing.',
      parameters: { 'competitor' => { 'type' => 'string' } }
    ) do |args, _raw|
      { 'response' => "#{args['competitor']} is $99/seat; we're $79." }
    end

    payload = JSON.generate(
      'function' => 'lookup_competitor',
      'argument' => { 'parsed' => [{ 'competitor' => 'ACME' }] },
      'call_id'  => 'c-1'
    )
    post '/swaig', payload, auth_header.merge('CONTENT_TYPE' => 'application/json')
    assert_equal 200, last_response.status
    assert_match(/ACME/, last_response.body)
    assert_match(/\$79/, last_response.body)
  end

  def test_swaig_post_missing_function_returns_400
    post '/swaig', '{}', auth_header.merge('CONTENT_TYPE' => 'application/json')
    assert_equal 400, last_response.status
  end

  def test_swaig_post_invalid_function_name_returns_400
    payload = JSON.generate('function' => '../etc/passwd')
    post '/swaig', payload, auth_header.merge('CONTENT_TYPE' => 'application/json')
    assert_equal 400, last_response.status
  end

  def test_swaig_post_unknown_function_returns_404
    payload = JSON.generate('function' => 'nope', 'argument' => { 'parsed' => [{}] })
    post '/swaig', payload, auth_header.merge('CONTENT_TYPE' => 'application/json')
    assert_equal 404, last_response.status
  end

  def test_swaig_unauthorized_returns_401
    post '/swaig', '{}'
    assert_equal 401, last_response.status
  end

  # ----- Sidecar pattern: non-agent SWML + tool + event sink ----------

  def test_sidecar_pattern_emits_verb_registers_tool_and_handles_events
    # 1. Build the SWML — answer + ai_sidecar verb config.
    @svc.answer
    @svc.document.add_verb('ai_sidecar', {
      'prompt' => 'real-time copilot',
      'lang' => 'en-US',
      'direction' => %w[remote-caller local-caller]
    })
    rendered = @svc.document.to_h
    verbs = rendered['sections']['main'].map { |v| v.keys.first }
    assert_includes verbs, 'answer'
    assert_includes verbs, 'ai_sidecar'

    # 2. Register a SWAIG tool the sidecar's LLM can call.
    @svc.define_tool(
      name: 'lookup_competitor',
      description: 'Look up competitor pricing.',
      parameters: { 'competitor' => { 'type' => 'string' } }
    ) do |args, _raw|
      { 'response' => "Pricing for #{args['competitor']}: $99" }
    end

    # 3. Register an event-sink endpoint via routing callback.
    events_seen = []
    @svc.register_routing_callback('/events') do |body|
      events_seen << (body && body['type'])
      { 'ok' => true }
    end

    # SWAIG dispatch end-to-end.
    payload = JSON.generate(
      'function' => 'lookup_competitor',
      'argument' => { 'parsed' => [{ 'competitor' => 'ACME' }] }
    )
    post '/swaig', payload, auth_header.merge('CONTENT_TYPE' => 'application/json')
    assert_equal 200, last_response.status
    assert_match(/ACME/, last_response.body)

    # Event sink end-to-end.
    post '/events', JSON.generate('type' => 'insight', 'tick_id' => 7),
         auth_header.merge('CONTENT_TYPE' => 'application/json')
    assert_equal 200, last_response.status
    assert_equal ['insight'], events_seen
  end
end
