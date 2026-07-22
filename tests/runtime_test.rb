# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Env vars the Runtime module sniffs. We snapshot and restore them around
# every test so nothing that ran before (e.g. the auth tests setting
# SWML_BASIC_AUTH_*) can leak in, and so the plain `ENV[...] = ...` we do
# inside the test body doesn't leak out to later test files.
module RuntimeEnvIsolation
  RUNTIME_ENV_VARS = %w[
    GATEWAY_INTERFACE
    AWS_LAMBDA_FUNCTION_NAME
    AWS_LAMBDA_FUNCTION_URL
    AWS_REGION
    LAMBDA_TASK_ROOT
    FUNCTION_TARGET
    K_SERVICE
    GOOGLE_CLOUD_PROJECT
    AZURE_FUNCTIONS_ENVIRONMENT
    FUNCTIONS_WORKER_RUNTIME
    AzureWebJobsStorage
    SWML_PROXY_URL_BASE
    SIGNALWIRE_SUPPRESS_RUN
  ].freeze

  def setup
    super
    @saved_env = RUNTIME_ENV_VARS.to_h { |k| [k, ENV.fetch(k, nil)] }
    RUNTIME_ENV_VARS.each { |k| ENV.delete(k) }
  end

  def teardown
    RUNTIME_ENV_VARS.each do |k|
      if @saved_env[k].nil?
        ENV.delete(k)
      else
        ENV[k] = @saved_env[k]
      end
    end
    super
  end
end

class RuntimeExecutionModeTest < Minitest::Test
  include RuntimeEnvIsolation

  def test_defaults_to_server
    assert_equal :server, SignalWire::Runtime.execution_mode
    refute_predicate SignalWire::Runtime, :lambda?
    refute_predicate SignalWire::Runtime, :serverless?
  end

  def test_detects_lambda_via_function_name
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'

    assert_equal :lambda, SignalWire::Runtime.execution_mode
    assert_predicate SignalWire::Runtime, :lambda?
    assert_predicate SignalWire::Runtime, :serverless?
  end

  def test_detects_lambda_via_task_root
    ENV['LAMBDA_TASK_ROOT'] = '/var/task'

    assert_equal :lambda, SignalWire::Runtime.execution_mode
  end

  def test_detects_cgi
    ENV['GATEWAY_INTERFACE'] = 'CGI/1.1'

    assert_equal :cgi, SignalWire::Runtime.execution_mode
    refute_predicate SignalWire::Runtime, :lambda?
    assert_predicate SignalWire::Runtime, :serverless?
  end

  def test_cgi_wins_over_lambda_when_both_set
    # Emulators sometimes set GATEWAY_INTERFACE on top of AWS_LAMBDA_*
    # We want to honor the stricter CGI contract in that case.
    ENV['GATEWAY_INTERFACE']        = 'CGI/1.1'
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'

    assert_equal :cgi, SignalWire::Runtime.execution_mode
  end

  def test_detects_google_cloud_function
    ENV['K_SERVICE'] = 'my-service'

    assert_equal :google_cloud_function, SignalWire::Runtime.execution_mode
    assert_predicate SignalWire::Runtime, :serverless?
  end

  def test_detects_google_cloud_function_via_function_target
    ENV['FUNCTION_TARGET'] = 'entry_point'

    assert_equal :google_cloud_function, SignalWire::Runtime.execution_mode
  end

  def test_detects_azure_function
    ENV['FUNCTIONS_WORKER_RUNTIME'] = 'python'

    assert_equal :azure_function, SignalWire::Runtime.execution_mode
    assert_predicate SignalWire::Runtime, :serverless?
  end

  def test_empty_env_var_is_treated_as_unset
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = ''

    assert_equal :server, SignalWire::Runtime.execution_mode
  end
end

# The suppress-run guard: SIGNALWIRE_SUPPRESS_RUN lets tooling (swaig-test
# --file / --list / --simulate-serverless) LOAD an example whose last line is a
# bare `agent.run` without booting a blocking WEBrick server — the example still
# serves normally when executed directly (env unset). ruby_R5 N1.
class RuntimeSuppressRunTest < Minitest::Test
  include RuntimeEnvIsolation

  def test_suppress_run_default_false
    assert_equal false, SignalWire::Runtime.suppress_run?
  end

  def test_suppress_run_true_when_set
    ENV['SIGNALWIRE_SUPPRESS_RUN'] = '1'

    assert_equal true, SignalWire::Runtime.suppress_run?
  end

  def test_suppress_run_empty_is_false
    ENV['SIGNALWIRE_SUPPRESS_RUN'] = ''

    assert_equal false, SignalWire::Runtime.suppress_run?
  end

  # An AgentBase whose script ends in `agent.run` must return immediately
  # (no server boot) when suppressed — the deterministic anti-hang for tooling.
  def test_agent_run_is_noop_when_suppressed
    ENV['SIGNALWIRE_SUPPRESS_RUN'] = '1'
    agent = SignalWire::AgentBase.new(name: 'test')

    assert_nil agent.run
  end
end

class RuntimeLambdaBaseUrlTest < Minitest::Test
  include RuntimeEnvIsolation

  def test_nil_when_no_lambda_signal
    assert_nil SignalWire::Runtime.lambda_base_url
  end

  def test_prefers_function_url_env
    ENV['AWS_LAMBDA_FUNCTION_URL'] = 'https://custom.lambda-url.us-west-2.on.aws'
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'ignore-me'
    ENV['AWS_REGION']               = 'ignore-me-too'

    assert_equal 'https://custom.lambda-url.us-west-2.on.aws',
                 SignalWire::Runtime.lambda_base_url
  end

  def test_strips_trailing_slash_from_function_url
    ENV['AWS_LAMBDA_FUNCTION_URL'] = 'https://custom.lambda-url.us-west-2.on.aws/'

    assert_equal 'https://custom.lambda-url.us-west-2.on.aws',
                 SignalWire::Runtime.lambda_base_url
  end

  def test_falls_back_to_function_name_and_region
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'
    ENV['AWS_REGION']               = 'eu-west-1'

    assert_equal 'https://my-func.lambda-url.eu-west-1.on.aws',
                 SignalWire::Runtime.lambda_base_url
  end

  def test_region_defaults_to_us_east1
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'

    assert_equal 'https://my-func.lambda-url.us-east-1.on.aws',
                 SignalWire::Runtime.lambda_base_url
  end
end
