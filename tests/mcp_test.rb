# frozen_string_literal: true

require 'minitest/autorun'
require 'json'

# Suppress logging during tests
ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# ===========================================================================
# Helper
# ===========================================================================

def make_mcp_agent
  agent = SignalWire::AgentBase.new(name: 'test-mcp', route: '/test')
  agent.enable_mcp_server
  define_weather_tool(agent)
  agent
end

def define_weather_tool(agent)
  agent.define_tool(
    name: 'get_weather',
    description: 'Get the weather for a location',
    parameters: {
      'location' => { 'type' => 'string', 'description' => 'City name' }
    }
  ) do |args, _raw|
    loc = args['location'] || 'unknown'
    SignalWire::Swaig::FunctionResult.new("72F sunny in #{loc}")
  end
end

def mcp_request(method, id: nil, params: nil)
  req = { 'jsonrpc' => '2.0', 'method' => method }
  req['id'] = id unless id.nil?
  req['params'] = params unless params.nil?
  req
end

# ===========================================================================
# MCP Server tests
# ===========================================================================

class MCPBuildToolListTest < Minitest::Test
  def test_build_tool_list
    agent = make_mcp_agent
    tools = agent._build_mcp_tool_list

    assert_equal 1, tools.length
    tool = tools[0]
    schema = tool['inputSchema']

    assert_equal 'get_weather', tool['name']
    assert_equal 'Get the weather for a location', tool['description']
    assert_equal 'object', schema['type']
    assert schema['properties'].key?('location')
  end
end

class MCPInitializeTest < Minitest::Test
  def test_initialize_handshake
    agent = make_mcp_agent
    params = { 'protocolVersion' => '2025-06-18', 'capabilities' => {},
               'clientInfo' => { 'name' => 'test', 'version' => '1.0' } }
    resp = agent._handle_mcp_request(mcp_request('initialize', id: 1, params: params))

    assert_equal '2.0', resp['jsonrpc']
    assert_equal 1, resp['id']
    assert resp.key?('result')
    result = resp['result']

    assert_equal '2025-06-18', result['protocolVersion']
    assert result['capabilities'].key?('tools')
  end
end

class MCPInitializedNotificationTest < Minitest::Test
  def test_initialized_notification
    agent = make_mcp_agent
    resp = agent._handle_mcp_request(mcp_request('notifications/initialized'))

    assert resp.key?('result')
  end
end

class MCPToolsListTest < Minitest::Test
  def test_tools_list
    agent = make_mcp_agent
    resp = agent._handle_mcp_request(mcp_request('tools/list', id: 2, params: {}))

    assert_equal 2, resp['id']
    tools = resp['result']['tools']

    assert_equal 1, tools.length
    assert_equal 'get_weather', tools[0]['name']
  end
end

class MCPToolsCallTest < Minitest::Test
  def test_tools_call
    agent = make_mcp_agent
    params = { 'name' => 'get_weather', 'arguments' => { 'location' => 'Orlando' } }
    resp = agent._handle_mcp_request(mcp_request('tools/call', id: 3, params: params))
    content = resp.dig('result', 'content')

    assert_equal 3, resp['id']
    refute resp.dig('result', 'isError')
    assert_equal 1, content.length
    assert_equal 'text', content[0]['type']
    assert_includes content[0]['text'], 'Orlando'
  end
end

class MCPToolsCallUnknownTest < Minitest::Test
  def test_tools_call_unknown
    agent = make_mcp_agent
    resp = agent._handle_mcp_request(mcp_request('tools/call', id: 4, params: { 'name' => 'nonexistent',
                                                                                'arguments' => {} }))

    assert resp.key?('error')
    assert_equal(-32_602, resp['error']['code'])
    assert_includes resp['error']['message'], 'nonexistent'
  end
end

class MCPUnknownMethodTest < Minitest::Test
  def test_unknown_method
    agent = make_mcp_agent
    resp = agent._handle_mcp_request(mcp_request('resources/list', id: 5, params: {}))

    assert resp.key?('error')
    assert_equal(-32_601, resp['error']['code'])
  end
end

class MCPPingTest < Minitest::Test
  def test_ping
    agent = make_mcp_agent
    resp = agent._handle_mcp_request(mcp_request('ping', id: 6))

    assert resp.key?('result')
  end
end

class MCPInvalidVersionTest < Minitest::Test
  def test_invalid_jsonrpc_version
    agent = make_mcp_agent
    resp = agent._handle_mcp_request(mcp_request('initialize', id: 7).merge('jsonrpc' => '1.0'))

    assert resp.key?('error')
    assert_equal(-32_600, resp['error']['code'])
  end
end

# ===========================================================================
# MCP Client tests (add_mcp_server)
# ===========================================================================

class MCPAddServerBasicTest < Minitest::Test
  def test_add_mcp_server_basic
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')
    agent.add_mcp_server('https://mcp.example.com/tools')

    servers = agent.instance_variable_get(:@mcp_servers)

    assert_equal 1, servers.length
    assert_equal 'https://mcp.example.com/tools', servers[0]['url']
  end
end

class MCPAddServerHeadersTest < Minitest::Test
  def test_add_mcp_server_with_headers
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')
    agent.add_mcp_server(
      'https://mcp.example.com/tools',
      headers: { 'Authorization' => 'Bearer sk-xxx' }
    )

    servers = agent.instance_variable_get(:@mcp_servers)

    assert_equal 'Bearer sk-xxx', servers[0]['headers']['Authorization']
  end
end

class MCPAddServerResourcesTest < Minitest::Test
  def test_add_mcp_server_with_resources
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')
    agent.add_mcp_server(
      'https://mcp.example.com/crm',
      resources: true,
      resource_vars: { 'caller_id' => '${caller_id_number}' }
    )

    servers = agent.instance_variable_get(:@mcp_servers)

    assert servers[0]['resources']
    assert_equal '${caller_id_number}', servers[0]['resource_vars']['caller_id']
  end
end

class MCPAddMultipleServersTest < Minitest::Test
  def test_add_multiple_servers
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')
    agent.add_mcp_server('https://mcp1.example.com')
    agent.add_mcp_server('https://mcp2.example.com')

    servers = agent.instance_variable_get(:@mcp_servers)

    assert_equal 2, servers.length
  end
end

class MCPMethodChainingTest < Minitest::Test
  def test_method_chaining
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')
    result = agent.add_mcp_server('https://mcp.example.com')

    assert_same agent, result
  end
end

class MCPEnableServerTest < Minitest::Test
  def test_enable_mcp_server
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')

    refute agent.instance_variable_get(:@mcp_server_enabled)

    result = agent.enable_mcp_server

    assert agent.instance_variable_get(:@mcp_server_enabled)
    assert_same agent, result
  end
end

class MCPServersInSwmlTest < Minitest::Test
  def test_mcp_servers_in_swml
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')
    agent.add_mcp_server('https://mcp.example.com/tools', headers: { 'Authorization' => 'Bearer key' })

    ai_verb = agent.render_swml['sections']['main'].find { |v| v.key?('ai') }

    refute_nil ai_verb, 'expected ai verb'
    servers = ai_verb['ai']['mcp_servers']

    refute_nil servers, 'expected mcp_servers in AI config'
    assert_equal 1, servers.length
    assert_equal 'https://mcp.example.com/tools', servers[0]['url']
  end
end
