# frozen_string_literal: true

# Cross-port parity tests for six methods that match the Python reference:
#
#   * REST::CrudWithAddresses#list_addresses        (signalwire.rest._base)
#   * REST::PaginatedIterator#__next__ / #__iter__  (signalwire.rest._pagination)
#   * AgentServer#register_global_routing_callback  (signalwire.agent_server)
#   * AgentBase#auto_map_sip_usernames              (signalwire.core.agent_base)
#   * Relay::Call#wait_for                          (signalwire.relay.call)
#
# Assertions are content-shaped: REST cases assert the exact request
# (verb + path + params) the SDK builds against a recording HTTP stub; the
# relay case drives a real event through the Call and asserts the matching
# event is returned. No live mock server is required.

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire/rest/rest_client'
require_relative '../lib/signalwire/server/agent_server'
require_relative '../lib/signalwire/agent/agent_base'
require_relative '../lib/signalwire/relay/constants'
require_relative '../lib/signalwire/relay/relay_event'
require_relative '../lib/signalwire/relay/call'

# Records every request instead of hitting the network, returning a canned
# response body so callers can also assert on the parsed result.
class RecordingHttp
  attr_reader :calls

  def initialize(response = {})
    @calls    = []
    @response = response
  end

  def get(path, params = nil, request_options: nil)
    @calls << { method: 'GET', path: path, params: params, request_options: request_options }
    @response
  end

  def post(path, body = nil, params: nil, request_options: nil)
    @calls << { method: 'POST', path: path, body: body, params: params, request_options: request_options }
    @response
  end

  def last
    @calls.last
  end
end

# --------------------------------------------------------------------------
# CrudWithAddresses#list_addresses
# --------------------------------------------------------------------------
class CrudWithAddressesParityTest < Minitest::Test
  def test_class_extends_crud_resource
    assert_operator SignalWire::REST::CrudWithAddresses, :<, SignalWire::REST::CrudResource,
                    'CrudWithAddresses must inherit the standard CRUD surface'
  end

  def test_list_addresses_builds_addresses_subpath
    http = RecordingHttp.new('data' => [{ 'id' => 'addr-1' }])
    res  = SignalWire::REST::CrudWithAddresses.new(http, '/api/fabric/resources/ai_agents')

    result = res.list_addresses('res-123')

    req = http.last

    assert_equal 'GET', req[:method]
    assert_equal '/api/fabric/resources/ai_agents/res-123/addresses', req[:path]
    assert_nil req[:params], 'no params → nil query, matching Python params or None'
    assert_equal [{ 'id' => 'addr-1' }], result['data']
  end

  def test_list_addresses_forwards_query_params
    http = RecordingHttp.new
    res  = SignalWire::REST::CrudWithAddresses.new(http, '/api/fabric/resources/ai_agents')

    res.list_addresses('res-123', page_size: 25, type: 'sip')

    req = http.last

    assert_equal '/api/fabric/resources/ai_agents/res-123/addresses', req[:path]
    assert_equal({ page_size: 25, type: 'sip' }, req[:params])
  end

  def test_fabric_resource_inherits_list_addresses_from_mixin
    # Python's FabricResource(CrudWithAddresses) inherits list_addresses
    # rather than declaring it. Mirror that hierarchy in the Ruby port.
    assert_operator SignalWire::REST::Namespaces::Generated::FabricResource, :<, SignalWire::REST::CrudWithAddresses
    refute_includes SignalWire::REST::Namespaces::Generated::FabricResource.public_instance_methods(false),
                    :list_addresses,
                    'list_addresses should be inherited, not redeclared on FabricResource'

    http = RecordingHttp.new
    SignalWire::REST::Namespaces::Generated::FabricResource
      .new(http, '/api/fabric/resources/ai_agents')
      .list_addresses('abc')

    assert_equal '/api/fabric/resources/ai_agents/abc/addresses', http.last[:path]
  end
end

# --------------------------------------------------------------------------
# PaginatedIterator#__next__ / #__iter__
# --------------------------------------------------------------------------
class PaginatedIteratorProtocolParityTest < Minitest::Test
  # Serves two pages then stops, mirroring a links.next cursor walk.
  class PagedHttp
    def initialize
      @page = 0
    end

    def get(_path, _params = nil, request_options: nil) # rubocop:disable Lint/UnusedMethodArgument
      @page += 1
      case @page
      when 1
        { 'data' => [{ 'id' => 1 }, { 'id' => 2 }],
          'links' => { 'next' => 'https://x.test/api?cursor=abc' } }
      when 2
        { 'data' => [{ 'id' => 3 }], 'links' => {} }
      else
        { 'data' => [], 'links' => {} }
      end
    end
  end

  def make_iterator
    SignalWire::REST::PaginatedIterator.new(PagedHttp.new, '/api/things')
  end

  def test_iter_returns_self
    iter = make_iterator

    assert_same iter, iter.__iter__, '__iter__ must return the iterator itself'
  end

  def test_next_yields_items_then_raises_stop_iteration
    iter = make_iterator

    assert_equal({ 'id' => 1 }, iter.__next__)
    assert_equal({ 'id' => 2 }, iter.__next__)
    assert_equal({ 'id' => 3 }, iter.__next__) # crosses the page boundary

    assert_raises(StopIteration) { iter.__next__ }
  end

  def test_next_drives_full_collection_across_pages
    iter = make_iterator
    collected = []
    loop do
      collected << iter.__next__
    rescue StopIteration
      break
    end

    assert_equal [{ 'id' => 1 }, { 'id' => 2 }, { 'id' => 3 }], collected
  end
end

# --------------------------------------------------------------------------
# AgentServer#register_global_routing_callback
# --------------------------------------------------------------------------
class RegisterGlobalRoutingCallbackParityTest < Minitest::Test
  # Minimal agent double that records register_routing_callback calls.
  class FakeAgent
    attr_reader :registered

    def initialize
      @registered = []
    end

    # Reference param order: (callback_fn, path="/sip").
    def register_routing_callback(callback_fn = nil, path = '/sip', &block)
      @registered << [path, block || callback_fn]
    end
  end

  def setup
    @server = SignalWire::AgentServer.new
    @a1 = FakeAgent.new
    @a2 = FakeAgent.new
    @server.register(@a1, route: '/one')
    @server.register(@a2, route: '/two')
  end

  def test_registers_callback_on_every_agent
    cb = ->(_req, _data) { 'route' }
    @server.register_global_routing_callback(cb, '/sw')

    [@a1, @a2].each do |agent|
      assert_equal 1, agent.registered.length
      path, block = agent.registered.first

      assert_equal '/sw', path
      assert_same cb, block
    end
  end

  def test_normalizes_path_leading_and_trailing_slash
    @server.register_global_routing_callback(->(_r, _d) {}, 'webhook/')

    assert_equal '/webhook', @a1.registered.first[0]
  end

  def test_accepts_block_form
    block = proc { 'x' }
    @server.register_global_routing_callback(nil, '/blk', &block)

    assert_same block, @a1.registered.first[1]
  end

  def test_returns_self_for_chaining
    assert_same @server, @server.register_global_routing_callback(->(_r, _d) {}, '/c')
  end

  def test_requires_a_callback
    assert_raises(ArgumentError) { @server.register_global_routing_callback(nil, '/none') }
  end
end

# --------------------------------------------------------------------------
# AgentBase#auto_map_sip_usernames
# --------------------------------------------------------------------------
class AutoMapSipUsernamesParityTest < Minitest::Test
  def usernames_for(name:, route:)
    agent = SignalWire::AgentBase.new(name: name, route: route, suppress_logs: true)
    agent.auto_map_sip_usernames
    agent.instance_variable_get(:@sip_usernames)
  end

  def test_registers_name_and_no_vowel_variant
    # "support" → name "support"; no-vowels "spprt" (len 5 > 2, differs).
    names = usernames_for(name: 'support', route: '/')

    assert_includes names, 'support'
    assert_includes names, 'spprt'
  end

  def test_registers_route_when_distinct_from_name
    names = usernames_for(name: 'Sales Bot', route: '/desk')
    # name cleaned to "salesbot"; route cleaned to "desk".
    assert_includes names, 'salesbot'
    assert_includes names, 'desk'
  end

  def test_skips_route_equal_to_name_and_dedups
    names = usernames_for(name: 'demo', route: '/demo')

    assert_includes names, 'demo'
    assert_equal names.uniq, names, 'usernames must be deduped like Python set'
    assert_equal 1, names.count('demo')
  end

  def test_short_name_has_no_vowel_stripped_variant
    # len("bot") == 3, not > 3 → no no-vowels variant registered.
    names = usernames_for(name: 'bot', route: '/')

    assert_includes names, 'bot'
    refute_includes names, 'bt'
  end

  def test_returns_self_for_chaining
    agent = SignalWire::AgentBase.new(name: 'x', suppress_logs: true)

    assert_same agent, agent.auto_map_sip_usernames
  end
end

# --------------------------------------------------------------------------
# Relay::Call#wait_for
# --------------------------------------------------------------------------
class CallWaitForParityTest < Minitest::Test
  class StubClient
    def execute(_method, _params)
      { 'code' => '200', 'message' => 'OK' }
    end
  end

  def make_call
    SignalWire::Relay::Call.new(
      StubClient.new,
      call_id: 'call-1', node_id: 'node-1', state: 'answered'
    )
  end

  # Dispatch a calling.call.state event with the given call_state.
  def dispatch_state(call, state)
    call._dispatch_event(
      'event_type' => 'calling.call.state',
      'params' => { 'call_id' => 'call-1', 'call_state' => state }
    )
  end

  def test_returns_matching_event
    call = make_call
    Thread.new do
      sleep 0.05
      dispatch_state(call, 'ringing')
    end

    event = call.wait_for('calling.call.state', timeout: 2)

    refute_nil event
    assert_equal 'calling.call.state', event.event_type
    assert_equal 'ringing', event.params['call_state']
  end

  def test_predicate_filters_non_matching_events
    call = make_call
    Thread.new do
      # First event fails the predicate, second satisfies it.
      sleep 0.03
      dispatch_state(call, 'ringing')
      sleep 0.03
      dispatch_state(call, 'answered')
    end

    answered = ->(e) { e.params['call_state'] == 'answered' }
    event = call.wait_for('calling.call.state', predicate: answered, timeout: 2)

    assert_equal 'answered', event.params['call_state']
  end

  def test_times_out_returning_nil
    call = make_call
    started = Time.now
    result = call.wait_for('calling.call.state', timeout: 0.1)

    assert_nil result
    assert_operator (Time.now - started), :>=, 0.1
  end

  def test_one_shot_listener_is_removed_after_wait
    call = make_call
    Thread.new do
      sleep 0.02
      dispatch_state(call, 'ringing')
    end
    call.wait_for('calling.call.state', timeout: 2)

    listeners = call.instance_variable_get(:@listeners)['calling.call.state'] || []

    assert_empty listeners, 'wait_for must remove its one-shot handler'
  end
end
