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

  agent
end

# ===========================================================================
# MCP Server tests
# ===========================================================================

class MCPBuildToolListTest < Minitest::Test
  def test_build_tool_list
    agent = make_mcp_agent
    tools = agent._build_mcp_tool_list

    assert_equal 1, tools.length
    assert_equal 'get_weather', tools[0]['name']
    assert_equal 'Get the weather for a location', tools[0]['description']
    assert tools[0].key?('inputSchema')
    assert_equal 'object', tools[0]['inputSchema']['type']
    assert tools[0]['inputSchema']['properties'].key?('location')
  end
end

class MCPInitializeTest < Minitest::Test
  def test_initialize_handshake
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '2.0',
                                       'id' => 1,
                                       'method' => 'initialize',
                                       'params' => {
                                         'protocolVersion' => '2025-06-18',
                                         'capabilities' => {},
                                         'clientInfo' => { 'name' => 'test', 'version' => '1.0' }
                                       }
                                     })

    assert_equal '2.0', resp['jsonrpc']
    assert_equal 1, resp['id']
    assert resp.key?('result')
    assert_equal '2025-06-18', resp['result']['protocolVersion']
    assert resp['result']['capabilities'].key?('tools')
  end
end

class MCPInitializedNotificationTest < Minitest::Test
  def test_initialized_notification
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '2.0',
                                       'method' => 'notifications/initialized'
                                     })

    assert resp.key?('result')
  end
end

class MCPToolsListTest < Minitest::Test
  def test_tools_list
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '2.0',
                                       'id' => 2,
                                       'method' => 'tools/list',
                                       'params' => {}
                                     })

    assert_equal 2, resp['id']
    tools = resp['result']['tools']

    assert_equal 1, tools.length
    assert_equal 'get_weather', tools[0]['name']
  end
end

class MCPToolsCallTest < Minitest::Test
  def test_tools_call
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '2.0',
                                       'id' => 3,
                                       'method' => 'tools/call',
                                       'params' => {
                                         'name' => 'get_weather',
                                         'arguments' => { 'location' => 'Orlando' }
                                       }
                                     })

    assert_equal 3, resp['id']
    assert_equal false, resp['result']['isError']
    content = resp['result']['content']

    assert_equal 1, content.length
    assert_equal 'text', content[0]['type']
    assert_includes content[0]['text'], 'Orlando'
  end
end

class MCPToolsCallUnknownTest < Minitest::Test
  def test_tools_call_unknown
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '2.0',
                                       'id' => 4,
                                       'method' => 'tools/call',
                                       'params' => { 'name' => 'nonexistent', 'arguments' => {} }
                                     })

    assert resp.key?('error')
    assert_equal(-32_602, resp['error']['code'])
    assert_includes resp['error']['message'], 'nonexistent'
  end
end

class MCPUnknownMethodTest < Minitest::Test
  def test_unknown_method
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '2.0',
                                       'id' => 5,
                                       'method' => 'resources/list',
                                       'params' => {}
                                     })

    assert resp.key?('error')
    assert_equal(-32_601, resp['error']['code'])
  end
end

class MCPPingTest < Minitest::Test
  def test_ping
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '2.0',
                                       'id' => 6,
                                       'method' => 'ping'
                                     })

    assert resp.key?('result')
  end
end

class MCPInvalidVersionTest < Minitest::Test
  def test_invalid_jsonrpc_version
    agent = make_mcp_agent
    resp = agent._handle_mcp_request({
                                       'jsonrpc' => '1.0',
                                       'id' => 7,
                                       'method' => 'initialize'
                                     })

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

    assert_equal true, servers[0]['resources']
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

    assert_equal false, agent.instance_variable_get(:@mcp_server_enabled)

    result = agent.enable_mcp_server

    assert_equal true, agent.instance_variable_get(:@mcp_server_enabled)
    assert_same agent, result
  end
end

class MCPServersInSwmlTest < Minitest::Test
  def test_mcp_servers_in_swml
    agent = SignalWire::AgentBase.new(name: 'test', route: '/test')
    agent.add_mcp_server(
      'https://mcp.example.com/tools',
      headers: { 'Authorization' => 'Bearer key' }
    )

    swml = agent.render_swml
    sections = swml['sections']['main']
    ai_verb = sections.find { |v| v.key?('ai') }

    refute_nil ai_verb, 'expected ai verb'

    ai_config = ai_verb['ai']

    assert ai_config.key?('mcp_servers'), 'expected mcp_servers in AI config'
    assert_equal 1, ai_config['mcp_servers'].length
    assert_equal 'https://mcp.example.com/tools', ai_config['mcp_servers'][0]['url']
  end
end
