# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Cross-language parity tests for
# SignalWire::Core::LoggingConfig.get_execution_mode and
# SignalWire::Utils.is_serverless_mode.
#
# Mirrors signalwire-python/tests/unit/utils/test_execution_mode.py:
# every branch of the env-var detection ladder must match the same
# precedence and return the same canonical string.
class ExecutionModeParityTest < Minitest::Test
  EXEC_ENV_VARS = %w[
    GATEWAY_INTERFACE
    AWS_LAMBDA_FUNCTION_NAME
    LAMBDA_TASK_ROOT
    FUNCTION_TARGET
    K_SERVICE
    GOOGLE_CLOUD_PROJECT
    AZURE_FUNCTIONS_ENVIRONMENT
    FUNCTIONS_WORKER_RUNTIME
    AzureWebJobsStorage
  ].freeze

  def setup
    super
    @saved = EXEC_ENV_VARS.to_h { |k| [k, ENV.fetch(k, nil)] }
    EXEC_ENV_VARS.each { |k| ENV.delete(k) }
  end

  def teardown
    EXEC_ENV_VARS.each do |k|
      if @saved[k].nil?
        ENV.delete(k)
      else
        ENV[k] = @saved[k]
      end
    end
    super
  end

  # ------------------------------------------------------------------
  # get_execution_mode — every branch.
  # ------------------------------------------------------------------

  def test_default_is_server
    assert_equal 'server', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_cgi_via_gateway_interface
    ENV['GATEWAY_INTERFACE'] = 'CGI/1.1'

    assert_equal 'cgi', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_lambda_via_function_name
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'

    assert_equal 'lambda', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_lambda_via_task_root
    ENV['LAMBDA_TASK_ROOT'] = '/var/task'

    assert_equal 'lambda', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_google_cloud_function_via_function_target
    ENV['FUNCTION_TARGET'] = 'my_handler'

    assert_equal 'google_cloud_function', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_google_cloud_function_via_k_service
    ENV['K_SERVICE'] = 'svc'

    assert_equal 'google_cloud_function', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_google_cloud_function_via_project
    ENV['GOOGLE_CLOUD_PROJECT'] = 'proj'

    assert_equal 'google_cloud_function', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_azure_function_via_environment
    ENV['AZURE_FUNCTIONS_ENVIRONMENT'] = 'Production'

    assert_equal 'azure_function', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_azure_function_via_worker_runtime
    ENV['FUNCTIONS_WORKER_RUNTIME'] = 'ruby'

    assert_equal 'azure_function', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_azure_function_via_web_jobs_storage
    ENV['AzureWebJobsStorage'] = 'DefaultEndpointsProtocol=https'

    assert_equal 'azure_function', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  # CGI must beat Lambda — cross-language precedence contract.
  def test_cgi_beats_lambda
    ENV['GATEWAY_INTERFACE']        = 'CGI/1.1'
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'

    assert_equal 'cgi', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_lambda_beats_google_cloud
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'
    ENV['FUNCTION_TARGET']          = 'h'

    assert_equal 'lambda', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  def test_google_cloud_beats_azure
    ENV['FUNCTION_TARGET']             = 'h'
    ENV['AZURE_FUNCTIONS_ENVIRONMENT'] = 'Production'

    assert_equal 'google_cloud_function', SignalWire::Core::LoggingConfig.get_execution_mode
  end

  # ------------------------------------------------------------------
  # is_serverless_mode.
  # ------------------------------------------------------------------

  def test_server_is_not_serverless
    refute SignalWire::Utils.is_serverless_mode
  end

  def test_lambda_is_serverless
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-fn'

    assert SignalWire::Utils.is_serverless_mode
  end

  # CGI is short-lived per request — counts as serverless.
  def test_cgi_is_serverless
    ENV['GATEWAY_INTERFACE'] = 'CGI/1.1'

    assert SignalWire::Utils.is_serverless_mode
  end

  def test_azure_is_serverless
    ENV['AZURE_FUNCTIONS_ENVIRONMENT'] = 'Production'

    assert SignalWire::Utils.is_serverless_mode
  end
end
