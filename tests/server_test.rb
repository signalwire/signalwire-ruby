# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'fileutils'
require 'logger'
require 'tmpdir'

require_relative '../lib/signalwire/server/agent_server'

# Simple mock agent for testing
class MockAgent
  attr_reader :name, :route

  def initialize(name:, route:)
    @name  = name
    @route = route
  end
end

class AgentServerTest < Minitest::Test
  def setup
    @server = SignalWire::AgentServer.new(host: '127.0.0.1', port: 4567)
  end

  def test_creation
    assert_equal '127.0.0.1', @server.host
    assert_equal 4567, @server.port
  end

  def test_default_creation
    server = SignalWire::AgentServer.new
    assert_equal '0.0.0.0', server.host
    assert_equal 3000, server.port
    assert_equal 'info', server.log_level
  end

  # --- Python parity: log_level constructor arg --------------------
  # Python: AgentServer(host, port, log_level="info")

  def test_log_level_default_is_info
    server = SignalWire::AgentServer.new
    assert_equal 'info', server.log_level
    refute_nil server.logger
  end

  def test_log_level_debug_lowers_threshold
    server = SignalWire::AgentServer.new(log_level: 'debug')
    assert_equal 'debug', server.log_level
    assert_equal ::Logger::DEBUG, server.logger.level
  end

  def test_log_level_warning_raises_threshold
    server = SignalWire::AgentServer.new(log_level: 'warning')
    assert_equal ::Logger::WARN, server.logger.level
  end

  def test_log_level_error_raises_threshold
    server = SignalWire::AgentServer.new(log_level: 'error')
    assert_equal ::Logger::ERROR, server.logger.level
  end

  def test_log_level_unknown_falls_back_to_info
    server = SignalWire::AgentServer.new(log_level: 'bogus')
    assert_equal ::Logger::INFO, server.logger.level
  end

  # --- Python parity: server.app exposes the Rack/FastAPI app ------
  # Python: ``server.app`` is the FastAPI instance.

  def test_app_returns_rack_app
    app = @server.app
    refute_nil app
    assert_respond_to app, :call
  end

  def test_app_is_memoised
    a = @server.app
    b = @server.app
    assert_same a, b
  end

  def test_app_routes_to_health_endpoint
    status, _, body = @server.app.call('PATH_INFO' => '/health')
    assert_equal '200', status
    data = JSON.parse(body.first)
    assert_equal 'ok', data['status']
  end

  # --- Python parity: server.logger is a real logger ---------------

  def test_logger_attribute_present
    refute_nil @server.logger
    assert_respond_to @server.logger, :info
    assert_respond_to @server.logger, :warn
  end

  # --- Python parity: run(event=, context=, host=, port=) ----------

  def test_run_routes_to_lambda_when_lambda_env_present
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'test-fn'
    begin
      result = @server.run(event: { 'path' => '/health', 'httpMethod' => 'GET' })
      assert_kind_of Hash, result
      assert_equal 200, result['statusCode']
      data = JSON.parse(result['body'])
      assert_equal 'ok', data['status']
    ensure
      ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
    end
  end

  def test_run_routes_to_cgi_when_gateway_interface_present
    ENV['GATEWAY_INTERFACE'] = 'CGI/1.1'
    ENV['PATH_INFO'] = '/health'
    ENV['REQUEST_METHOD'] = 'GET'
    begin
      result = @server.run
      assert_kind_of String, result
      assert_includes result, 'Status: 200'
      assert_includes result, '"status":"ok"'
    ensure
      ENV.delete('GATEWAY_INTERFACE')
      ENV.delete('PATH_INFO')
      ENV.delete('REQUEST_METHOD')
    end
  end

  def test_detect_execution_mode_returns_server_default
    assert_equal 'server', @server._detect_execution_mode
  end

  def test_detect_execution_mode_lambda
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'fn'
    assert_equal 'lambda', @server._detect_execution_mode
  ensure
    ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
  end

  def test_detect_execution_mode_cgi
    ENV['GATEWAY_INTERFACE'] = 'CGI/1.1'
    assert_equal 'cgi', @server._detect_execution_mode
  ensure
    ENV.delete('GATEWAY_INTERFACE')
  end

  def test_register_agent
    agent = MockAgent.new(name: 'test', route: '/test')
    @server.register(agent)

    assert_equal agent, @server.get_agent('/test')
  end

  def test_register_with_explicit_route
    agent = MockAgent.new(name: 'test', route: '/original')
    @server.register(agent, route: '/custom')

    assert_equal agent, @server.get_agent('/custom')
    assert_nil @server.get_agent('/original')
  end

  def test_register_auto_prefixes_slash
    agent = MockAgent.new(name: 'test', route: '/test')
    @server.register(agent, route: 'no_slash')

    assert_equal agent, @server.get_agent('/no_slash')
  end

  def test_register_duplicate_raises
    agent1 = MockAgent.new(name: 'a', route: '/route')
    agent2 = MockAgent.new(name: 'b', route: '/route')
    @server.register(agent1)

    assert_raises(ArgumentError) { @server.register(agent2) }
  end

  def test_unregister
    agent = MockAgent.new(name: 'test', route: '/test')
    @server.register(agent)
    assert_equal agent, @server.get_agent('/test')

    removed = @server.unregister('/test')
    assert_equal agent, removed
    assert_nil @server.get_agent('/test')
  end

  def test_unregister_nonexistent
    assert_nil @server.unregister('/nonexistent')
  end

  def test_get_agents
    a1 = MockAgent.new(name: 'a', route: '/a')
    a2 = MockAgent.new(name: 'b', route: '/b')
    @server.register(a1)
    @server.register(a2)

    agents = @server.get_agents
    assert_equal 2, agents.size
    assert_equal a1, agents['/a']
    assert_equal a2, agents['/b']
  end

  def test_get_agent_not_found
    assert_nil @server.get_agent('/nonexistent')
  end

  def test_rack_app_health_endpoint
    agent = MockAgent.new(name: 'test', route: '/test')
    @server.register(agent)

    app = @server.rack_app
    env = { 'PATH_INFO' => '/health' }
    status, headers, body = app.call(env)

    assert_equal '200', status
    assert_equal 'application/json', headers['Content-Type']
    data = JSON.parse(body.first)
    assert_equal 'ok', data['status']
    assert_includes data['agents'], '/test'
  end

  def test_rack_app_healthz_endpoint
    app = @server.rack_app
    status, _, _ = app.call({ 'PATH_INFO' => '/healthz' })
    assert_equal '200', status
  end

  def test_rack_app_root_endpoint
    agent = MockAgent.new(name: 'test', route: '/test')
    @server.register(agent)

    app = @server.rack_app
    status, _, body = app.call({ 'PATH_INFO' => '/' })

    assert_equal '200', status
    data = JSON.parse(body.first)
    assert_equal 'SignalWire Agent Server', data['service']
    assert_includes data['agents'], '/test'
  end

  def test_rack_app_agent_route
    agent = MockAgent.new(name: 'test', route: '/test')
    @server.register(agent)

    app = @server.rack_app
    status, _, body = app.call({ 'PATH_INFO' => '/test' })

    assert_equal '200', status
    data = JSON.parse(body.first)
    assert_equal '/test', data['agent']
    assert_equal 'registered', data['status']
  end

  def test_rack_app_404
    app = @server.rack_app
    status, _, body = app.call({ 'PATH_INFO' => '/nonexistent' })

    assert_equal '404', status
    data = JSON.parse(body.first)
    assert_equal 'Not found', data['error']
  end

  def test_rack_app_callable_agent
    # Agent that responds to call
    callable_agent = Proc.new { |_env| ['200', { 'Content-Type' => 'text/plain' }, ['hello']] }
    @server.register(callable_agent, route: '/callable')

    app = @server.rack_app
    status, _, body = app.call({ 'PATH_INFO' => '/callable' })

    assert_equal '200', status
    assert_equal 'hello', body.first
  end

  def test_setup_sip_routing
    agent = MockAgent.new(name: 'test', route: '/test')
    @server.register(agent)
    @server.setup_sip_routing(route: '/sip', auto_map: true)

    # No crash is good enough for now; SIP routing is configuration-level
    assert true
  end

  def test_register_sip_username
    @server.register_sip_username('alice', '/agent1')
    assert true  # No crash
  end

  def test_fluent_register
    agent = MockAgent.new(name: 'test', route: '/test')
    result = @server.register(agent)
    assert_same @server, result
  end
end

# =========================================================================
# Static file serving tests
# =========================================================================
class AgentServerStaticFilesTest < Minitest::Test
  def setup
    @server = SignalWire::AgentServer.new(host: '127.0.0.1', port: 4567)

    # Create a temporary directory with test files
    @tmpdir = File.join(Dir.tmpdir, "swaig_test_static_#{$$}")
    FileUtils.mkdir_p(@tmpdir)
    File.write(File.join(@tmpdir, 'index.html'), '<html><body>Hello</body></html>')
    File.write(File.join(@tmpdir, 'style.css'), 'body { color: red; }')
    File.write(File.join(@tmpdir, 'data.json'), '{"key":"value"}')
    FileUtils.mkdir_p(File.join(@tmpdir, 'sub'))
    File.write(File.join(@tmpdir, 'sub', 'page.html'), '<html>Sub</html>')
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.directory?(@tmpdir)
  end

  def test_serve_static_files_returns_self
    result = @server.serve_static_files(@tmpdir, '/static')
    assert_same @server, result
  end

  def test_serve_static_files_nonexistent_dir_raises
    assert_raises(ArgumentError) do
      @server.serve_static_files('/nonexistent/path/xyz', '/static')
    end
  end

  def test_serve_index_html
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    status, headers, body = app.call({ 'PATH_INFO' => '/static/' })
    assert_equal '200', status
    assert_equal 'text/html', headers['Content-Type']
    assert_includes body.first, 'Hello'
  end

  def test_serve_css_file
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    status, headers, body = app.call({ 'PATH_INFO' => '/static/style.css' })
    assert_equal '200', status
    assert_equal 'text/css', headers['Content-Type']
    assert_includes body.first, 'color: red'
  end

  def test_serve_json_file
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    status, headers, body = app.call({ 'PATH_INFO' => '/static/data.json' })
    assert_equal '200', status
    assert_equal 'application/json', headers['Content-Type']
  end

  def test_serve_sub_directory_file
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    status, _, body = app.call({ 'PATH_INFO' => '/static/sub/page.html' })
    assert_equal '200', status
    assert_includes body.first, 'Sub'
  end

  def test_security_headers_on_static
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    _, headers, _ = app.call({ 'PATH_INFO' => '/static/index.html' })
    assert_equal 'nosniff', headers['x-content-type-options']
    assert_equal 'DENY', headers['x-frame-options']
    assert_includes headers['cache-control'], 'no-store'
  end

  def test_path_traversal_blocked
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    status, _, _ = app.call({ 'PATH_INFO' => '/static/../../../etc/passwd' })
    assert_equal '403', status
  end

  def test_nonexistent_file_falls_through
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    status, _, _ = app.call({ 'PATH_INFO' => '/static/nonexistent.txt' })
    # Should fall through to 404 since no agent matches either
    assert_equal '404', status
  end

  def test_static_route_without_trailing_slash_serves_index
    @server.serve_static_files(@tmpdir, '/static')
    app = @server.rack_app
    status, _, body = app.call({ 'PATH_INFO' => '/static' })
    assert_equal '200', status
    assert_includes body.first, 'Hello'
  end
end
