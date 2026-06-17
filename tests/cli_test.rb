# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'net/http'
require 'uri'
require 'socket'

# Suppress logging during tests
ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Load the CLI module
load File.expand_path('../bin/swaig-test', __dir__)

class SwaigTestCLIParsingTest < Minitest::Test
  def test_parse_dump_swml
    cli = SwaigTest::CLI.new(['--url', 'http://user:pass@localhost:3000/agent', '--dump-swml'])

    assert_equal 'http://user:pass@localhost:3000/agent', cli.options[:url]
    assert cli.options[:dump_swml]
    refute cli.options[:list_tools]
    assert_nil cli.options[:exec]
  end

  def test_parse_list_tools
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@host:80/', '--list-tools'])

    assert cli.options[:list_tools]
    refute cli.options[:dump_swml]
  end

  def test_parse_exec_with_params
    cli = SwaigTest::CLI.new([
                               '--url', 'http://u:p@host:80/',
                               '--exec', 'get_weather',
                               '--param', 'city=Seattle',
                               '--param', 'units=metric'
                             ])

    assert_equal 'get_weather', cli.options[:exec]
    assert_equal 'Seattle', cli.options[:params]['city']
    assert_equal 'metric', cli.options[:params]['units']
  end

  def test_parse_raw_flag
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@host:80/', '--dump-swml', '--raw'])

    assert cli.options[:raw]
  end

  def test_parse_verbose_flag
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@host:80/', '--dump-swml', '--verbose'])

    assert cli.options[:verbose]
  end

  def test_param_value_parsing_integer
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--exec', 'f', '--param', 'count=42'])

    assert_equal 42, cli.options[:params]['count']
  end

  def test_param_value_parsing_float
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--exec', 'f', '--param', 'temp=98.6'])

    assert_in_delta 98.6, cli.options[:params]['temp']
  end

  def test_param_value_parsing_boolean_true
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--exec', 'f', '--param', 'flag=true'])

    assert_equal true, cli.options[:params]['flag']
  end

  def test_param_value_parsing_boolean_false
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--exec', 'f', '--param', 'flag=false'])

    assert_equal false, cli.options[:params]['flag']
  end

  def test_param_value_parsing_null
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--exec', 'f', '--param', 'val=null'])

    assert_nil cli.options[:params]['val']
  end

  def test_param_value_parsing_string
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--exec', 'f', '--param', 'name=John Doe'])

    assert_equal 'John Doe', cli.options[:params]['name']
  end

  def test_missing_url_exits
    assert_raises(SystemExit) do
      cli = SwaigTest::CLI.new(['--dump-swml'])
      cli.run
    end
  end

  def test_no_action_exits
    assert_raises(SystemExit) do
      cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/'])
      cli.run
    end
  end

  def test_multiple_actions_exits
    assert_raises(SystemExit) do
      cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--dump-swml', '--list-tools'])
      cli.run
    end
  end
end

# Integration tests that start a real WEBrick server and test the CLI against it
class SwaigTestCLIIntegrationTest < Minitest::Test
  def setup
    @port = find_available_port

    @agent = SignalWire::AgentBase.new(
      name: 'cli_test_agent',
      basic_auth: %w[testuser testpass],
      port: @port,
      host: '127.0.0.1'
    )
    @agent.set_prompt_text('You are a test agent')
    @agent.define_tool(
      name: 'greet',
      description: 'Greet someone by name',
      parameters: {
        'name' => { 'type' => 'string', 'description' => 'Person name' }
      }
    ) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("Hello, #{args['name']}!")
    end

    @rack_app = @agent.rack_app

    # Start a real server in a thread
    require 'webrick'
    require 'rackup/handler/webrick'

    @server = WEBrick::HTTPServer.new(
      BindAddress: '127.0.0.1',
      Port: @port,
      Logger: WEBrick::Log.new(File.open(File::NULL, 'w'), WEBrick::Log::FATAL),
      AccessLog: []
    )
    @server.mount('/', Rackup::Handler::WEBrick, @rack_app)
    @server_thread = Thread.new { @server.start }

    # Wait for server to be ready
    wait_for_server('127.0.0.1', @port)
  end

  def teardown
    @server&.shutdown
    @server_thread&.join(5)
  end

  def test_dump_swml_integration
    output = capture_stdout do
      cli = SwaigTest::CLI.new([
                                 '--url', "http://testuser:testpass@127.0.0.1:#{@port}/",
                                 '--dump-swml'
                               ])
      cli.run
    end

    swml = JSON.parse(output)

    assert_equal '1.0.0', swml['version']
    assert swml.key?('sections')
  end

  def test_list_tools_integration
    output = capture_stdout do
      cli = SwaigTest::CLI.new([
                                 '--url', "http://testuser:testpass@127.0.0.1:#{@port}/",
                                 '--list-tools'
                               ])
      cli.run
    end

    assert_includes output, 'greet'
    assert_includes output, 'Greet someone by name'
  end

  def test_exec_function_integration
    output = capture_stdout do
      cli = SwaigTest::CLI.new([
                                 '--url', "http://testuser:testpass@127.0.0.1:#{@port}/",
                                 '--exec', 'greet',
                                 '--param', 'name=World'
                               ])
      cli.run
    end

    result = JSON.parse(output)

    assert_equal 'Hello, World!', result['response']
  end

  def test_exec_raw_output
    output = capture_stdout do
      cli = SwaigTest::CLI.new([
                                 '--url', "http://testuser:testpass@127.0.0.1:#{@port}/",
                                 '--exec', 'greet',
                                 '--param', 'name=Test',
                                 '--raw'
                               ])
      cli.run
    end

    # Raw output should be compact (single line)
    refute_includes output.strip, "\n"
    result = JSON.parse(output)

    assert_equal 'Hello, Test!', result['response']
  end

  private

  def find_available_port
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    port
  end

  def wait_for_server(host, port, timeout: 5)
    deadline = Time.now + timeout
    loop do
      TCPSocket.new(host, port).close
      return
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      raise "Server did not start within #{timeout}s" if Time.now > deadline

      sleep 0.05
    end
  end

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end
end

# In-process file-mode tests: verify `--file PATH --list-tools` loads the
# script, finds the SWML::Service subclass, walks its tool registry, and
# prints each tool. NO HTTP, NO simulator — this is the path that surfaces
# SWAIG tools registered on a non-AgentBase Service (the case URL mode
# can't see, since plain Service `render_main_swml` returns the document
# only).
class SwaigTestCLIFileModeTest < Minitest::Test
  EXAMPLES_DIR = File.expand_path('../examples', __dir__)

  def standalone_path
    File.join(EXAMPLES_DIR, 'swmlservice_swaig_standalone.rb')
  end

  def sidecar_path
    File.join(EXAMPLES_DIR, 'swmlservice_ai_sidecar.rb')
  end

  def capture_stdout
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end

  def test_file_option_recognised
    cli = SwaigTest::CLI.new(['--file', standalone_path, '--list-tools'])

    assert_equal standalone_path, cli.options[:file]
    assert cli.options[:list_tools]
  end

  def test_file_mode_lists_at_least_one_tool_for_standalone_example
    skip 'standalone example missing' unless File.exist?(standalone_path)
    output = capture_stdout do
      SwaigTest::CLI.new(['--file', standalone_path, '--list-tools']).run
    end

    assert_includes output, 'SWAIG Functions:'
    assert_includes output, 'lookup_competitor'
    assert_includes output, 'competitor'
    refute_includes output, 'No SWAIG functions found.'
  end

  def test_file_mode_lists_at_least_one_tool_for_sidecar_example
    skip 'sidecar example missing' unless File.exist?(sidecar_path)
    output = capture_stdout do
      SwaigTest::CLI.new(['--file', sidecar_path, '--list-tools']).run
    end

    assert_includes output, 'lookup_competitor'
    assert_includes output, 'competitor'
  end

  def test_file_mode_rejects_url_combo
    assert_raises(SystemExit) do
      SwaigTest::CLI.new(['--file', standalone_path,
                          '--url', 'http://u:p@h:80/',
                          '--list-tools']).run
    end
  end

  def test_file_mode_rejects_simulate_serverless_combo
    assert_raises(SystemExit) do
      SwaigTest::CLI.new(['--file', standalone_path,
                          '--simulate-serverless', 'lambda',
                          '--list-tools']).run
    end
  end

  def test_file_mode_requires_list_tools_action
    assert_raises(SystemExit) do
      SwaigTest::CLI.new(['--file', standalone_path]).run
    end
  end

  def test_file_mode_rejects_missing_file
    assert_raises(SystemExit) do
      SwaigTest::CLI.new(['--file', '/no/such/file.rb', '--list-tools']).run
    end
  end
end
