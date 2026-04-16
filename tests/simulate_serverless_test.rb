# frozen_string_literal: true

# Tests for `bin/swaig-test --simulate-serverless lambda`.
#
# These cover the non-negotiables from the porting-sdk checklist:
#   - env vars set during invocation and restored after, both on the
#     happy path and when the agent raises;
#   - SWML_PROXY_URL_BASE is cleared during simulation so the Lambda
#     base URL actually drives webhook construction;
#   - non-root routes round-trip correctly through the adapter (the
#     load-bearing regression the prior agent fixed);
#   - unimplemented platforms (gcf, azure, cgi) are rejected with a
#     clear error.

require 'minitest/autorun'
require 'json'
require 'stringio'
require 'tempfile'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'
require_relative 'runtime_test' # pull in RuntimeEnvIsolation

# Load the CLI (defines SwaigTest module)
load File.expand_path('../bin/swaig-test', __dir__)

module SimulateServerlessTestHelpers
  # Write an agent source file that defines an `AGENT` top-level constant
  # at the given route, plus one tool per entry in `tools`. Each tool is
  # a hash: { name:, description:, block: ->(args, raw) { ... } }.
  # Returns the Tempfile (caller is responsible for unlinking).
  def write_agent_file(route:, auth: ['u', 'p'], tools: default_tools, extra: '')
    file = Tempfile.new(['agent', '.rb'])
    file.write(<<~RUBY)
      require 'signalwire'

      AGENT = SignalWire::AgentBase.new(
        name:       'simtest',
        route:      #{route.inspect},
        basic_auth: #{auth.inspect}
      )
      AGENT.set_prompt_text('Hello from the simulator test')
    RUBY
    tools.each do |t|
      file.write(<<~RUBY)

        AGENT.define_tool(
          name:        #{t[:name].inspect},
          description: #{t[:description].inspect},
          parameters:  #{t.fetch(:parameters, {}).inspect}
        ) do |args, raw|
          #{t.fetch(:body, "SignalWire::Swaig::FunctionResult.new('ok')")}
        end
      RUBY
    end
    file.write("\n#{extra}\n") if extra && !extra.empty?
    file.flush
    file
  end

  def default_tools
    [
      {
        name: 'echo',
        description: 'Echo back a message',
        parameters: { 'message' => { 'type' => 'string' } },
        body: "SignalWire::Swaig::FunctionResult.new(\"echo: \#{args['message']}\")"
      }
    ]
  end

  def run_cli(argv)
    cli = SwaigTest::CLI.new(argv)
    cli.run
  end

  def capture_cli(argv)
    out = StringIO.new
    err = StringIO.new
    orig_out = $stdout
    orig_err = $stderr
    $stdout = out
    $stderr = err
    status = :ok
    begin
      run_cli(argv)
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = orig_out
      $stderr = orig_err
    end
    # Purge the AGENT constant so subsequent tests can reload cleanly.
    Object.send(:remove_const, :AGENT) if Object.const_defined?(:AGENT)
    [out.string, err.string, status]
  end

  # Run an SwaigTest::ServerlessSimulator directly so we can assert on
  # what it sets/clears WITHOUT shelling out to a subprocess.
  def with_simulator(platform: 'lambda')
    sim = SwaigTest::ServerlessSimulator.new(platform)
    sim.activate
    yield sim
  ensure
    sim&.deactivate
  end
end

# ==========================================================================
# Simulator env-var lifecycle
# ==========================================================================
class SimulatorEnvLifecycleTest < Minitest::Test
  include RuntimeEnvIsolation
  include SimulateServerlessTestHelpers

  def test_activate_sets_lambda_env_vars
    assert_nil ENV['AWS_LAMBDA_FUNCTION_NAME']

    with_simulator do
      refute_nil ENV['AWS_LAMBDA_FUNCTION_NAME'],
                 'AWS_LAMBDA_FUNCTION_NAME should be set during simulation'
      refute_nil ENV['LAMBDA_TASK_ROOT'],
                 'LAMBDA_TASK_ROOT should be set during simulation'
      refute_nil ENV['AWS_REGION'],
                 'AWS_REGION should be set during simulation'
      assert_equal :lambda, SignalWire::Runtime.execution_mode
    end

    # After deactivate, everything should be back to unset.
    assert_nil ENV['AWS_LAMBDA_FUNCTION_NAME']
    assert_nil ENV['LAMBDA_TASK_ROOT']
    assert_nil ENV['AWS_REGION']
    assert_equal :server, SignalWire::Runtime.execution_mode
  end

  def test_deactivate_restores_pre_existing_values
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'pre-existing'

    with_simulator do
      # Simulator replaces it with its preset
      refute_equal 'pre-existing', ENV['AWS_LAMBDA_FUNCTION_NAME']
    end

    # And restores the caller's original value
    assert_equal 'pre-existing', ENV['AWS_LAMBDA_FUNCTION_NAME']
  end

  def test_activate_clears_swml_proxy_url_base
    ENV['SWML_PROXY_URL_BASE'] = 'https://proxy.example.com'

    with_simulator do
      assert_nil ENV['SWML_PROXY_URL_BASE'],
                 'SWML_PROXY_URL_BASE must be cleared during simulation so Lambda URL takes effect'
    end

    # Outer value must come back afterwards
    assert_equal 'https://proxy.example.com', ENV['SWML_PROXY_URL_BASE']
  end

  def test_env_restored_when_block_raises
    ENV['AWS_LAMBDA_FUNCTION_NAME']   = 'outer-value'
    ENV['SWML_PROXY_URL_BASE']        = 'https://outer.example.com'

    assert_raises(RuntimeError) do
      sim = SwaigTest::ServerlessSimulator.new('lambda')
      sim.with_simulation do
        # Simulator is active; sanity-check then raise
        refute_equal 'outer-value', ENV['AWS_LAMBDA_FUNCTION_NAME']
        assert_nil ENV['SWML_PROXY_URL_BASE']
        raise 'boom'
      end
    end

    # ensure-path restoration
    assert_equal 'outer-value',               ENV['AWS_LAMBDA_FUNCTION_NAME']
    assert_equal 'https://outer.example.com', ENV['SWML_PROXY_URL_BASE']
  end
end

# ==========================================================================
# --simulate-serverless lambda --dump-swml
# ==========================================================================
class SimulateLambdaDumpSwmlTest < Minitest::Test
  include RuntimeEnvIsolation
  include SimulateServerlessTestHelpers

  def teardown
    @agent_file&.close
    @agent_file&.unlink
    super
  end

  def test_dump_swml_on_root_route_uses_simulator_lambda_url
    @agent_file = write_agent_file(route: '/')

    out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'lambda', '--dump-swml', '--raw']
    )

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    swml = JSON.parse(out)
    url = swml['sections']['main'].find { |v| v.key?('ai') }['ai']['SWAIG']['defaults']['web_hook_url']
    assert_includes url, 'lambda-url.us-east-1.on.aws',
                    'simulator must drive the Lambda base URL'
    assert_includes url, '/swaig'
  end

  def test_dump_swml_on_non_root_route_preserves_route
    # The load-bearing regression from the Lambda bug: the agent is
    # mounted at a non-root route, so the webhook URL must contain
    # /my-agent/swaig. If `_base_url` ever drops the route, this fails.
    @agent_file = write_agent_file(route: '/my-agent')

    out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'lambda', '--dump-swml', '--raw']
    )

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    swml = JSON.parse(out)
    url = swml['sections']['main'].find { |v| v.key?('ai') }['ai']['SWAIG']['defaults']['web_hook_url']
    assert_includes url, '/my-agent/swaig',
                    "expected '/my-agent/swaig' in webhook URL, got #{url.inspect}"
    refute_match %r{lambda-url\.[^/]+/swaig$}, url,
                 "route must not be dropped between base URL and /swaig, got #{url.inspect}"
  end

  def test_simulator_clears_outer_swml_proxy_url_base
    # This is the mock_env.py behavior: SWML_PROXY_URL_BASE is set in
    # the outer shell, but once --simulate-serverless lambda is in
    # effect the resulting SWML must use a Lambda-style URL.
    ENV['SWML_PROXY_URL_BASE'] = 'https://outer-proxy.example.com'

    @agent_file = write_agent_file(route: '/my-agent')

    out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'lambda', '--dump-swml', '--raw']
    )

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    swml = JSON.parse(out)
    url = swml['sections']['main'].find { |v| v.key?('ai') }['ai']['SWAIG']['defaults']['web_hook_url']

    refute_includes url, 'outer-proxy.example.com',
                    'outer SWML_PROXY_URL_BASE must not leak into simulated webhook URL'
    assert_match %r{lambda-url\.[^/]+\.on\.aws/my-agent/swaig}, url,
                 "expected Lambda-style URL with route, got #{url.inspect}"

    # And the outer env var must be restored by the time the CLI exits.
    assert_equal 'https://outer-proxy.example.com', ENV['SWML_PROXY_URL_BASE'],
                 'outer SWML_PROXY_URL_BASE must be restored after CLI completes'
  end

  def test_dump_swml_without_subaction_renders_and_exits
    # The porting-guide spec: `--simulate-serverless lambda` without
    # --dump-swml / --exec still renders the SWML and exits.
    @agent_file = write_agent_file(route: '/')

    out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'lambda', '--raw']
    )

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    parsed = JSON.parse(out)
    assert parsed['sections']['main'].any? { |v| v.key?('ai') },
           'default render path should emit a SWML document with an ai verb'
  end
end

# ==========================================================================
# --simulate-serverless lambda --exec
# ==========================================================================
class SimulateLambdaExecTest < Minitest::Test
  include RuntimeEnvIsolation
  include SimulateServerlessTestHelpers

  def teardown
    @agent_file&.close
    @agent_file&.unlink
    super
  end

  def test_exec_dispatches_through_lambda_adapter
    @agent_file = write_agent_file(route: '/')

    out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'lambda',
       '--exec', 'echo', '--param', 'message=hello', '--raw']
    )

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    result = JSON.parse(out)
    assert_equal 'echo: hello', result['response']
  end

  def test_exec_on_non_root_route_still_works
    @agent_file = write_agent_file(route: '/my-agent')

    out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'lambda',
       '--exec', 'echo', '--param', 'message=routed', '--raw']
    )

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    result = JSON.parse(out)
    assert_equal 'echo: routed', result['response']
  end

  def test_env_restored_when_tool_raises
    # A tool body that raises must still leave the env clean.
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'outer-func'
    ENV['SWML_PROXY_URL_BASE']      = 'https://outer.example.com'

    @agent_file = write_agent_file(
      route: '/',
      tools: [{
        name:        'boom',
        description: 'Always raises',
        parameters:  {},
        body:        "raise 'simulated tool failure'"
      }]
    )

    # The CLI catches tool errors at the dispatcher level (which raises
    # because the handler returns 500). We only care that the env is
    # restored after the CLI exits.
    _out, _err, _status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'lambda',
       '--exec', 'boom', '--raw']
    )

    assert_equal 'outer-func',                ENV['AWS_LAMBDA_FUNCTION_NAME']
    assert_equal 'https://outer.example.com', ENV['SWML_PROXY_URL_BASE']
  end
end

# ==========================================================================
# Platform validation
# ==========================================================================
class SimulateServerlessPlatformValidationTest < Minitest::Test
  include RuntimeEnvIsolation
  include SimulateServerlessTestHelpers

  def teardown
    @agent_file&.close
    @agent_file&.unlink
    super
  end

  def test_gcf_is_rejected_with_clear_error
    @agent_file = write_agent_file(route: '/')

    out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'gcf', '--dump-swml']
    )

    refute_equal :ok, status, 'gcf must not be accepted until Phase 9 ships for it'
    assert_includes err, 'gcf'
    assert_includes err, 'not implemented'
  end

  def test_azure_is_rejected_with_clear_error
    @agent_file = write_agent_file(route: '/')

    _out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'azure', '--dump-swml']
    )

    refute_equal :ok, status
    assert_includes err, 'azure'
    assert_includes err, 'not implemented'
  end

  def test_cgi_is_rejected_with_clear_error
    @agent_file = write_agent_file(route: '/')

    _out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'cgi', '--dump-swml']
    )

    refute_equal :ok, status
    assert_includes err, 'cgi'
    assert_includes err, 'not implemented'
  end

  def test_unknown_platform_is_rejected
    @agent_file = write_agent_file(route: '/')

    _out, err, status = capture_cli(
      [@agent_file.path, '--simulate-serverless', 'jellybean', '--dump-swml']
    )

    refute_equal :ok, status
    assert_includes err, 'jellybean'
  end

  def test_missing_agent_file_is_rejected
    _out, err, status = capture_cli(
      ['--simulate-serverless', 'lambda', '--dump-swml']
    )

    refute_equal :ok, status
    assert_includes err, 'requires a positional agent file'
  end

  def test_agent_file_not_found_is_rejected
    _out, err, status = capture_cli(
      ['/nonexistent/path/agent.rb', '--simulate-serverless', 'lambda', '--dump-swml']
    )

    refute_equal :ok, status
    assert_includes err, 'not found'
  end
end
