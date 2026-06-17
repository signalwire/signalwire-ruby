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
  def write_agent_file(route:, auth: %w[u p], tools: default_tools, extra: '')
    file = Tempfile.new(['agent', '.rb'])
    file.write(agent_header_source(route, auth))
    tools.each { |t| file.write(tool_source(t)) }
    file.write("\n#{extra}\n") if extra && !extra.empty?
    file.flush
    file
  end

  def agent_header_source(route, auth)
    <<~RUBY
      require 'signalwire'

      AGENT = SignalWire::AgentBase.new(
        name:       'simtest',
        route:      #{route.inspect},
        basic_auth: #{auth.inspect}
      )
      AGENT.set_prompt_text('Hello from the simulator test')
    RUBY
  end

  def tool_source(tool)
    <<~RUBY

      AGENT.define_tool(
        name:        #{tool[:name].inspect},
        description: #{tool[:description].inspect},
        parameters:  #{tool.fetch(:parameters, {}).inspect}
      ) do |args, raw|
        #{tool.fetch(:body, "SignalWire::Swaig::FunctionResult.new('ok')")}
      end
    RUBY
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
    status = with_captured_io(out, err) { run_cli(argv) }
    # Purge the AGENT constant so subsequent tests can reload cleanly.
    Object.send(:remove_const, :AGENT) if Object.const_defined?(:AGENT)
    [out.string, err.string, status]
  end

  # Redirect $stdout/$stderr to the given IOs while yielding; returns the
  # CLI's exit status (:ok, or the SystemExit status if it exited).
  def with_captured_io(out, err)
    orig = [$stdout, $stderr]
    $stdout = out
    $stderr = err
    yield
    :ok
  rescue SystemExit => e
    e.status
  ensure
    $stdout, $stderr = orig
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

  # Parse a --dump-swml JSON document and return the AI SWAIG default
  # web_hook_url — the field every Lambda-URL regression test asserts on.
  def webhook_url(dump_swml_json)
    swml = JSON.parse(dump_swml_json)
    swml['sections']['main'].find { |v| v.key?('ai') }['ai']['SWAIG']['defaults']['web_hook_url']
  end

  # Run the CLI in --simulate-serverless lambda --dump-swml --raw mode for the
  # given agent file. Returns [out, err, status].
  def dump_swml_cli(agent_path)
    capture_cli([agent_path, '--simulate-serverless', 'lambda', '--dump-swml', '--raw'])
  end
end

# ==========================================================================
# Simulator env-var lifecycle
# ==========================================================================
class SimulatorEnvLifecycleTest < Minitest::Test
  include RuntimeEnvIsolation
  include SimulateServerlessTestHelpers

  LAMBDA_ENV_VARS = %w[AWS_LAMBDA_FUNCTION_NAME LAMBDA_TASK_ROOT AWS_REGION].freeze

  def test_activate_sets_lambda_env_vars
    LAMBDA_ENV_VARS.each { |v| assert_nil ENV.fetch(v, nil) }

    with_simulator do
      LAMBDA_ENV_VARS.each { |v| refute_nil ENV.fetch(v, nil), "#{v} should be set during simulation" }
      assert_equal :lambda, SignalWire::Runtime.execution_mode
    end

    # After deactivate, everything should be back to unset.
    LAMBDA_ENV_VARS.each { |v| assert_nil ENV.fetch(v, nil) }
    assert_equal :server, SignalWire::Runtime.execution_mode
  end

  def test_deactivate_restores_pre_existing_values
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'pre-existing'

    with_simulator do
      # Simulator replaces it with its preset
      refute_equal 'pre-existing', ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
    end

    # And restores the caller's original value
    assert_equal 'pre-existing', ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
  end

  def test_activate_clears_swml_proxy_url_base
    ENV['SWML_PROXY_URL_BASE'] = 'https://proxy.example.com'

    with_simulator do
      assert_nil ENV.fetch('SWML_PROXY_URL_BASE', nil),
                 'SWML_PROXY_URL_BASE must be cleared during simulation so Lambda URL takes effect'
    end

    # Outer value must come back afterwards
    assert_equal 'https://proxy.example.com', ENV.fetch('SWML_PROXY_URL_BASE', nil)
  end

  def test_env_restored_when_block_raises
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'outer-value'
    ENV['SWML_PROXY_URL_BASE'] = 'https://outer.example.com'

    sim = SwaigTest::ServerlessSimulator.new('lambda')
    assert_raises(RuntimeError) { sim.with_simulation { raise_after_env_check } }

    # ensure-path restoration
    assert_equal 'outer-value',               ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
    assert_equal 'https://outer.example.com', ENV.fetch('SWML_PROXY_URL_BASE', nil)
  end

  # Simulator is active here; sanity-check the swapped env, then raise.
  def raise_after_env_check
    refute_equal 'outer-value', ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
    assert_nil ENV.fetch('SWML_PROXY_URL_BASE', nil)
    raise 'boom'
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

    out, err, status = dump_swml_cli(@agent_file.path)

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    url = webhook_url(out)

    assert_includes url, 'lambda-url.us-east-1.on.aws',
                    'simulator must drive the Lambda base URL'
    assert_includes url, '/swaig'
  end

  def test_dump_swml_on_non_root_route_preserves_route
    # The load-bearing regression from the Lambda bug: the agent is
    # mounted at a non-root route, so the webhook URL must contain
    # /my-agent/swaig. If `_base_url` ever drops the route, this fails.
    @agent_file = write_agent_file(route: '/my-agent')

    out, err, status = dump_swml_cli(@agent_file.path)

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    url = webhook_url(out)

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

    out, err, status = dump_swml_cli(@agent_file.path)

    assert_equal :ok, status, "CLI exited non-zero: #{err}"
    assert_lambda_url_without_proxy_leak(webhook_url(out))

    # And the outer env var must be restored by the time the CLI exits.
    assert_equal 'https://outer-proxy.example.com', ENV.fetch('SWML_PROXY_URL_BASE', nil),
                 'outer SWML_PROXY_URL_BASE must be restored after CLI completes'
  end

  def assert_lambda_url_without_proxy_leak(url)
    refute_includes url, 'outer-proxy.example.com',
                    'outer SWML_PROXY_URL_BASE must not leak into simulated webhook URL'
    assert_match %r{lambda-url\.[^/]+\.on\.aws/my-agent/swaig}, url,
                 "expected Lambda-style URL with route, got #{url.inspect}"
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

  def raising_tool
    { name: 'boom', description: 'Always raises', parameters: {}, body: "raise 'simulated tool failure'" }
  end

  def test_env_restored_when_tool_raises
    # A tool body that raises must still leave the env clean.
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'outer-func'
    ENV['SWML_PROXY_URL_BASE']      = 'https://outer.example.com'

    @agent_file = write_agent_file(route: '/', tools: [raising_tool])

    # The CLI catches tool errors at the dispatcher level (which raises
    # because the handler returns 500). We only care that the env is
    # restored after the CLI exits.
    capture_cli([@agent_file.path, '--simulate-serverless', 'lambda', '--exec', 'boom', '--raw'])

    assert_equal 'outer-func',                ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
    assert_equal 'https://outer.example.com', ENV.fetch('SWML_PROXY_URL_BASE', nil)
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

    _, err, status = capture_cli(
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
