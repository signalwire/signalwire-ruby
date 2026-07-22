# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

module SignalWire
  # Runtime environment detection.
  #
  # Detects the execution environment (plain server, AWS Lambda, CGI,
  # Google Cloud Functions, Azure Functions) by inspecting well-known
  # environment variables set by each platform.
  #
  # This is the Ruby counterpart to the Python SDK's
  # +signalwire.core.logging_config.get_execution_mode+.
  module Runtime
    MODES = %i[server lambda cgi google_cloud_function azure_function unknown].freeze

    # Determine the current execution mode.
    #
    # Returns one of:
    # - +:cgi+   - running under a CGI gateway (GATEWAY_INTERFACE is set)
    # - +:lambda+ - running under AWS Lambda
    # - +:google_cloud_function+ - Google Cloud Functions / Cloud Run
    # - +:azure_function+ - Azure Functions
    # - +:server+ - long-running HTTP server (the default)
    #
    # Detection order matters: CGI is checked before Lambda because a
    # Lambda function invoked through an emulator that also sets
    # GATEWAY_INTERFACE should still be treated as CGI.
    #
    # @return [Symbol] one of the values in {MODES}
    # Ordered (mode, signal-env-vars) detection table. Order is load-bearing:
    # CGI is checked before Lambda so a Lambda emulator that also sets
    # GATEWAY_INTERFACE is still treated as CGI.
    MODE_SIGNALS = [
      [:cgi,                    %w[GATEWAY_INTERFACE]],
      [:lambda,                 %w[AWS_LAMBDA_FUNCTION_NAME LAMBDA_TASK_ROOT]],
      [:google_cloud_function,  %w[FUNCTION_TARGET K_SERVICE GOOGLE_CLOUD_PROJECT]],
      [:azure_function,         %w[AZURE_FUNCTIONS_ENVIRONMENT FUNCTIONS_WORKER_RUNTIME AzureWebJobsStorage]]
    ].freeze

    def self.execution_mode
      MODE_SIGNALS.each { |mode, vars| return mode if env_present?(*vars) }
      :server
    end

    # True when SIGNALWIRE_SUPPRESS_RUN is set (non-empty). When set, an agent's
    # blocking entry points (AgentBase#run / #serve, SWMLService#serve,
    # AgentServer#run) return immediately WITHOUT booting a server. This is the
    # deterministic anti-hang for tooling that must LOAD an example whose last
    # line is a bare `agent.run` — swaig-test (--file / --list / exec /
    # --simulate-serverless) sets it before Kernel.load. Unset (the normal case),
    # `run`/`serve` behave exactly as before, so an example still serves when run
    # directly. (ruby_R5 N1.)
    def self.suppress_run?
      env_present?('SIGNALWIRE_SUPPRESS_RUN')
    end

    # True when any of the named environment variables is set and non-empty.
    # @return [Boolean]
    def self.env_present?(*names)
      names.any? { |name| (v = ENV.fetch(name, nil)) && !v.empty? }
    end
    private_class_method :env_present?

    # True when the SDK is running inside AWS Lambda.
    # @return [Boolean]
    def self.lambda?
      execution_mode == :lambda
    end

    # True when the SDK is running inside any serverless platform.
    # @return [Boolean]
    def self.serverless?
      mode = execution_mode
      %i[lambda cgi google_cloud_function azure_function].include?(mode)
    end

    # Construct the base URL for the current Lambda function.
    #
    # Prefers +AWS_LAMBDA_FUNCTION_URL+ when set; otherwise falls back to
    # the standard Function URL shape built from +AWS_LAMBDA_FUNCTION_NAME+
    # and +AWS_REGION+. Returns +nil+ when neither signal is present.
    #
    # The returned URL never has a trailing slash and never contains a
    # path component, so callers must append the agent's route themselves.
    #
    # @return [String, nil]
    def self.lambda_base_url
      explicit = ENV.fetch('AWS_LAMBDA_FUNCTION_URL', nil)
      return explicit.chomp('/') if explicit && !explicit.empty?

      function_name = ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
      return nil if function_name.nil? || function_name.empty?

      region = ENV.fetch('AWS_REGION', nil)
      region = 'us-east-1' if region.nil? || region.empty?

      "https://#{function_name}.lambda-url.#{region}.on.aws"
    end
  end
end
