# frozen_string_literal: true

# MCPGatewaySkill CLIENT tests.
#
# The skill connects to a RUNNING MCP Gateway over HTTP, authenticates
# (bearer OR HTTP-basic), enumerates the gateway's services + tools, and
# registers each MCP tool as a SWAIG function. These tests drive the REAL skill
# code path against a local WEBrick fixture that stands in for the gateway —
# so the actual Net::HTTP request/parse/register code runs, not a stand-in.
#
# verify_ssl is proven two ways: (a) it defaults SECURE (true) and (b) the flag
# flips the Net::HTTP verify_mode between VERIFY_PEER and VERIFY_NONE — the wire
# manifestation of the config, not a stored no-op.

require 'minitest/autorun'
require 'webrick'
require 'socket'
require 'json'
require 'net/http'
require 'openssl'

require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/mcp_gateway'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

# A loopback MCP-Gateway fixture on an ephemeral port. Serves /health,
# /services, /services/<name>/tools, and /services/<name>/call so the skill's
# real HTTP path runs end-to-end.
class MCPGatewayFixture
  attr_reader :port, :requests

  WEATHER_TOOL = {
    'name' => 'lookup',
    'description' => 'Look up the weather',
    'inputSchema' => {
      'properties' => { 'city' => { 'type' => 'string', 'description' => 'City' } },
      'required' => ['city']
    }
  }.freeze

  def initialize
    @requests = []
    @port = pick_free_port
    @server = WEBrick::HTTPServer.new(
      Port: @port, BindAddress: '127.0.0.1',
      Logger: WEBrick::Log.new(File.open(File::NULL, 'w'), WEBrick::Log::FATAL),
      AccessLog: []
    )
    mount
    @thread = Thread.new { @server.start }
    wait_until_ready
  end

  def base_url = "http://127.0.0.1:#{@port}"

  def shutdown
    @server&.shutdown
    @thread&.join(5)
  end

  private

  def pick_free_port
    s = TCPServer.new('127.0.0.1', 0)
    port = s.addr[1]
    s.close
    port
  end

  def wait_until_ready
    20.times do
      TCPSocket.new('127.0.0.1', @port).close
      return
    rescue Errno::ECONNREFUSED
      sleep 0.05
    end
  end

  def mount
    @server.mount_proc('/health') { |_req, res| res.body = '{"status":"ok"}' }
    route('/services', 'GET') { JSON.generate(['weather']) }
    route('/services/weather/tools', 'GET') { JSON.generate('tools' => [WEATHER_TOOL]) }
    route('/services/weather/call', 'POST') { JSON.generate('result' => 'It is sunny') }
  end

  # Record each hit (method, path, headers, body) then serve the block's body.
  def route(path, method, &)
    @server.mount_proc(path) do |req, res|
      @requests << [method, path, req.header, req.body]
      res.body = yield
    end
  end
end

# Shared fixture lifecycle + factory helper for the mcp_gateway skill tests. The
# concrete test classes below (registration/auth, and verify_ssl/hooks) inherit
# it so each stays a focused, small unit.
class MCPGatewayTestBase < Minitest::Test
  def setup
    # The fixture binds a loopback (private) port; allow it past the SSRF guard,
    # exactly as the spider / wikipedia network-backed skill tests do.
    @prev_allow = ENV.fetch('SWML_ALLOW_PRIVATE_URLS', nil)
    ENV['SWML_ALLOW_PRIVATE_URLS'] = 'true'
    @fixture = MCPGatewayFixture.new
  end

  def teardown
    @fixture.shutdown
    ENV['SWML_ALLOW_PRIVATE_URLS'] = @prev_allow
  end

  def build(params = {})
    base = { 'gateway_url' => @fixture.base_url, 'auth_token' => 'tok-123' }
    SignalWire::Skills::SkillRegistry.get_factory('mcp_gateway').call(base.merge(params))
  end

  # A bare skill built directly (bypassing the auth_token default) so auth-shape
  # tests can supply their own credentials.
  def build_raw(params)
    SignalWire::Skills::SkillRegistry.get_factory('mcp_gateway')
                                     .call({ 'gateway_url' => @fixture.base_url }.merge(params))
  end

  # base classes carry no tests themselves.
  def self.runnable_methods = self == MCPGatewayTestBase ? [] : super
end

# Tool registration + gateway proxying.
class MCPGatewayRegistrationTest < MCPGatewayTestBase
  def test_register_tools_registers_gateway_tools_as_swaig_functions
    skill = build

    assert skill.setup, 'setup should succeed against the healthy fixture'
    tool = skill.register_tools.find { |t| t[:name] == 'mcp_weather_lookup' }

    refute_nil tool, 'the gateway tool must register as a prefixed SWAIG function'
    assert_equal '[weather] Look up the weather', tool[:description]
    assert_equal(['city'], tool[:required])
    assert tool[:parameters].key?('city')
    assert_respond_to tool[:handler], :call, 'each tool carries a callable handler'
  end

  def test_registered_tool_handler_calls_gateway_and_returns_result
    skill = build
    skill.setup
    tool = skill.register_tools.find { |t| t[:name] == 'mcp_weather_lookup' }
    result = tool[:handler].call({ 'city' => 'Orlando' }, { 'call_id' => 'call-1' })

    assert_instance_of SignalWire::Swaig::FunctionResult, result
    assert_equal 'It is sunny', result.response
    assert_gateway_call('lookup', { 'city' => 'Orlando' }, 'call-1')
  end

  # The POST to /services/weather/call carried the expected tool + args + session.
  def assert_gateway_call(tool, args, session_id)
    call = @fixture.requests.find { |r| r[1] == '/services/weather/call' }
    body = JSON.parse(call[3])

    assert_equal tool, body['tool']
    assert_equal args, body['arguments']
    assert_equal session_id, body['session_id']
  end

  def test_custom_tool_prefix
    skill = build('tool_prefix' => 'x_')
    skill.setup
    names = skill.register_tools.map { |t| t[:name] }

    assert_includes names, 'x_weather_lookup'
  end
end

# verify_ssl (secure default + verify_mode flip), auth shapes, and hook accessors.
class MCPGatewayConfigTest < MCPGatewayTestBase
  def test_verify_ssl_defaults_true
    schema = build.get_parameter_schema

    assert_equal true, schema['verify_ssl']['default']
    # And the ivar reads secure by default (no verify_ssl param supplied).
    skill = build
    skill.setup

    assert_equal true, skill.instance_variable_get(:@verify_ssl)
  end

  def test_verify_ssl_secure_default_wires_verify_peer
    skill = build # no verify_ssl → secure default
    skill.setup
    http = capture_open_http(skill, 'https://gateway.example.com')

    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode,
                 'a secure-default skill must set VERIFY_PEER'
  end

  def test_verify_ssl_false_flips_to_verify_none
    skill = build('verify_ssl' => false)
    skill.setup
    http = capture_open_http(skill, 'https://gateway.example.com')

    assert_equal OpenSSL::SSL::VERIFY_NONE, http.verify_mode,
                 'verify_ssl:false must flip the transport to VERIFY_NONE'
  end

  # Drive the REAL #open_http builder (private) so the assertion is on the wired
  # Net::HTTP object, not a re-derivation of the flag.
  def capture_open_http(skill, url)
    skill.send(:open_http, URI(url))
  end

  def test_bearer_auth_header
    skill = build # auth_token set
    skill.setup
    req = skill.send(:build_request, 'GET', URI("#{@fixture.base_url}/services"), nil)

    assert_equal 'Bearer tok-123', req['Authorization']
  end

  def test_basic_auth_when_no_token
    skill = build_raw('auth_user' => 'u', 'auth_password' => 'p')

    assert skill.setup, 'basic-auth setup should succeed'
    req = skill.send(:build_request, 'GET', URI("#{@fixture.base_url}/services"), nil)

    assert_equal "Basic #{['u:p'].pack('m0')}", req['Authorization']
  end

  def test_setup_fails_without_any_auth
    skill = build_raw({})

    refute skill.setup, 'setup must fail when neither token nor basic-auth creds are given'
  end

  def test_get_hints_includes_service_names
    skill = build('services' => [{ 'name' => 'weather' }])
    hints = skill.get_hints

    assert_includes hints, 'MCP'
    assert_includes hints, 'weather'
  end

  def test_get_global_data
    skill = build
    skill.setup
    data = skill.get_global_data

    assert_equal @fixture.base_url, data['mcp_gateway_url']
  end

  def test_get_prompt_sections_lists_services
    skill = build('services' => [{ 'name' => 'weather', 'tools' => '*' }])
    sections = skill.get_prompt_sections

    assert_equal 'MCP Gateway Integration', sections[0]['title']
    assert(sections[0]['bullets'].any? { |b| b.include?('weather (all tools)') })
  end
end
