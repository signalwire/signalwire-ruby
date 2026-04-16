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
    def self.execution_mode
      # CGI environment (e.g. Apache mod_cgi)
      return :cgi if ENV['GATEWAY_INTERFACE'] && !ENV['GATEWAY_INTERFACE'].empty?

      # AWS Lambda
      if (ENV['AWS_LAMBDA_FUNCTION_NAME'] && !ENV['AWS_LAMBDA_FUNCTION_NAME'].empty?) ||
         (ENV['LAMBDA_TASK_ROOT'] && !ENV['LAMBDA_TASK_ROOT'].empty?)
        return :lambda
      end

      # Google Cloud Functions / Cloud Run
      if (ENV['FUNCTION_TARGET'] && !ENV['FUNCTION_TARGET'].empty?) ||
         (ENV['K_SERVICE'] && !ENV['K_SERVICE'].empty?) ||
         (ENV['GOOGLE_CLOUD_PROJECT'] && !ENV['GOOGLE_CLOUD_PROJECT'].empty?)
        return :google_cloud_function
      end

      # Azure Functions
      if (ENV['AZURE_FUNCTIONS_ENVIRONMENT'] && !ENV['AZURE_FUNCTIONS_ENVIRONMENT'].empty?) ||
         (ENV['FUNCTIONS_WORKER_RUNTIME'] && !ENV['FUNCTIONS_WORKER_RUNTIME'].empty?) ||
         (ENV['AzureWebJobsStorage'] && !ENV['AzureWebJobsStorage'].empty?)
        return :azure_function
      end

      :server
    end

    # True when the SDK is running inside AWS Lambda.
    # @return [Boolean]
    def self.lambda?
      execution_mode == :lambda
    end

    # True when the SDK is running inside any serverless platform.
    # @return [Boolean]
    def self.serverless?
      mode = execution_mode
      mode == :lambda || mode == :cgi ||
        mode == :google_cloud_function || mode == :azure_function
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
      explicit = ENV['AWS_LAMBDA_FUNCTION_URL']
      return explicit.chomp('/') if explicit && !explicit.empty?

      function_name = ENV['AWS_LAMBDA_FUNCTION_NAME']
      return nil if function_name.nil? || function_name.empty?

      region = ENV['AWS_REGION']
      region = 'us-east-1' if region.nil? || region.empty?

      "https://#{function_name}.lambda-url.#{region}.on.aws"
    end
  end
end
