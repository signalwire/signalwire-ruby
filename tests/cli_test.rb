# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'net/http'
require 'uri'
require 'stringio'

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
    cli = SwaigTest::CLI.new(['--dump-swml'])

    assert_raises(SystemExit) { cli.run }
  end

  def test_no_action_exits
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/'])

    assert_raises(SystemExit) { cli.run }
  end

  def test_multiple_actions_exits
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--dump-swml', '--list-tools'])

    assert_raises(SystemExit) { cli.run }
  end
end

# --parse-only / --dry-run: validate the invocation's arguments and exit WITHOUT
# loading the agent, touching the filesystem, or hitting the network. Valid args
# print exactly "parse OK" and exit 0; invalid args exit 2 without printing
# "parse OK". Canonical contract mirrored by every SDK port.
class SwaigTestCLIParseOnlyTest < Minitest::Test
  # Run the CLI and return [captured_stdout, exit_status]. run_parse_only always
  # exits (0 on success, 2 on bad args), so we trap the SystemExit.
  def run_parse_only(argv)
    old_stdout = $stdout
    $stdout = StringIO.new
    SwaigTest::CLI.new(argv).run
  rescue SystemExit => e
    [$stdout.string, e.status]
  ensure
    $stdout = old_stdout
  end

  def test_parse_only_flag_recognised
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--list-tools', '--parse-only'])

    assert cli.options[:parse_only]
  end

  def test_dry_run_is_an_exact_alias
    cli = SwaigTest::CLI.new(['--url', 'http://u:p@h:80/', '--list-tools', '--dry-run'])

    assert cli.options[:parse_only]
  end

  def test_valid_invocation_prints_parse_ok_and_exits_zero
    out, status = run_parse_only(['--url', 'http://u:p@h:80/', '--list-tools', '--parse-only'])

    assert_equal 'parse OK', out.strip
    assert_equal 0, status
  end

  # Position-independent: --parse-only is honoured even when it TRAILS an --exec
  # invocation (the position the DOC-CLI gate appends it).
  def test_position_independent_after_exec
    out, status = run_parse_only(
      ['--url', 'http://u:p@h:80/', '--exec', 'foo', '--param', 'bar=1', '--parse-only']
    )

    assert_equal 'parse OK', out.strip
    assert_equal 0, status
  end

  # File existence is a runtime concern, not an argument-validity concern: a
  # syntactically valid invocation naming a non-existent agent file still
  # reports "parse OK" (the flag never touches the filesystem).
  def test_does_not_require_agent_file_to_exist
    out, status = run_parse_only(
      ['/definitely/not/here.rb', '--simulate-serverless', 'lambda', '--list-tools', '--parse-only']
    )

    assert_equal 'parse OK', out.strip
    assert_equal 0, status
    refute_includes out, 'not found'
  end

  def test_mutually_exclusive_actions_exit_two_without_parse_ok
    out, status = run_parse_only(['--url', 'http://u:p@h:80/', '--dump-swml', '--list-tools', '--parse-only'])

    assert_equal 2, status
    refute_includes out, 'parse OK'
  end

  def test_missing_mode_exits_two_without_parse_ok
    out, status = run_parse_only(['--parse-only'])

    assert_equal 2, status
    refute_includes out, 'parse OK'
  end
end

# Integration tests that start a real WEBrick server and test the CLI against it
class SwaigTestCLIIntegrationTest < Minitest::Test
  include TestHelper::Helpers

  def setup
    @port = find_available_port
    @agent = build_test_agent(@port)
    @rack_app = @agent.rack_app
    @server = build_server(@port, @rack_app)
    @server_thread = Thread.new { @server.start }
    wait_for_server('127.0.0.1', @port)
  end

  def build_test_agent(port)
    agent = SignalWire::AgentBase.new(
      name: 'cli_test_agent', basic_auth: %w[testuser testpass], port: port, host: '127.0.0.1'
    )
    agent.set_prompt_text('You are a test agent')
    define_greet_tool(agent)
    agent
  end

  def define_greet_tool(agent)
    agent.define_tool(
      name: 'greet',
      description: 'Greet someone by name',
      parameters: { 'name' => { 'type' => 'string', 'description' => 'Person name' } }, handler: nil
    ) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("Hello, #{args['name']}!")
    end
  end

  def build_server(port, rack_app)
    require 'webrick'
    require 'rackup/handler/webrick'
    server = WEBrick::HTTPServer.new(
      BindAddress: '127.0.0.1',
      Port: port,
      Logger: WEBrick::Log.new(File.open(File::NULL, 'w'), WEBrick::Log::FATAL),
      AccessLog: []
    )
    server.mount('/', Rackup::Handler::WEBrick, rack_app)
    server
  end

  def teardown
    @server&.shutdown
    @server_thread&.join(5)
  end

  def test_dump_swml_integration
    output = run_cli('--dump-swml')

    swml = JSON.parse(output)

    assert_equal '1.0.0', swml['version']
    assert swml.key?('sections')
  end

  def test_list_tools_integration
    output = run_cli('--list-tools')

    assert_includes output, 'greet'
    assert_includes output, 'Greet someone by name'
  end

  def test_exec_function_integration
    output = run_cli('--exec', 'greet', '--param', 'name=World')

    result = JSON.parse(output)

    assert_equal 'Hello, World!', result['response']
  end

  def test_exec_raw_output
    output = run_cli('--exec', 'greet', '--param', 'name=Test', '--raw')

    # Raw output should be compact (single line)
    refute_includes output.strip, "\n"
    result = JSON.parse(output)

    assert_equal 'Hello, Test!', result['response']
  end

  private

  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  # Base URL for the in-test server with credentials.
  def server_url
    "http://testuser:testpass@127.0.0.1:#{@port}/"
  end

  # Run the CLI with +extra_args+ (prepended with --url server_url) and return
  # its captured stdout.
  def run_cli(*extra_args)
    capture_stdout do
      SwaigTest::CLI.new(['--url', server_url, *extra_args]).run
    end
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

# #45 regression: the agent-discovery scan (AgentFileLoader.discovered_agent)
# iterates Object.constants + Object.const_get. On Ruby 3.2+, resolving the
# SortedSet autoload stub RAISES (RuntimeError "has been extracted from the
# `set` library"). Before the fix a raising const_get aborted the whole scan,
# so `swaig-test my_agent.rb` crashed for any agent NOT bound to an AGENT
# constant (the README quickstart style). These tests define a raising
# autoload stub and assert the scan survives it and still finds the agent.
class SwaigTestDiscoveryScanTest < Minitest::Test
  def teardown
    %i[BrokenAutoloadFixture QuickstartAgentFixture].each do |c|
      Object.send(:remove_const, c) if Object.const_defined?(c, false)
    end
  end

  # A top-level constant whose const_get raises StandardError — the same shape
  # as the SortedSet autoload stub that crashed the scan.
  def install_raising_constant
    Object.autoload(:BrokenAutoloadFixture, '/nonexistent/raises_on_resolve_xyz')
    # Redefine const_get so resolving the fixture raises RuntimeError (matching
    # SortedSet), not the LoadError a bare autoload-miss would give — proving the
    # `rescue StandardError` guard, which is what the real bug needs.
    def Object.const_get(name, *args)
      raise 'BrokenAutoloadFixture raises on resolve' if name == :BrokenAutoloadFixture

      super
    end
  end

  def uninstall_raising_constant
    class << Object
      remove_method(:const_get)
    end
  end

  def test_scan_survives_a_raising_autoload_and_finds_the_agent
    agent = SignalWire::AgentBase.new(name: 'quickstart')
    Object.const_set(:QuickstartAgentFixture, agent)
    install_raising_constant

    found = SwaigTest::AgentFileLoader.discovered_agent

    assert_same agent, found,
                'scan must skip the raising constant and still find the agent'
  ensure
    uninstall_raising_constant
  end

  def test_scan_does_not_raise_when_a_constant_resolution_raises
    install_raising_constant

    # No agent defined: the scan should return nil (not crash) when it walks
    # past the raising constant.
    assert_nil SwaigTest::AgentFileLoader.discovered_agent
  ensure
    uninstall_raising_constant
  end
end
