# frozen_string_literal: true

# Serverless / deployment-mode detection.
#
# {SignalWire::Core::LoggingConfig.get_execution_mode} reads the environment
# and reports which platform the process is running on. Order of precedence
# (FIRST match wins):
#
#   1. GATEWAY_INTERFACE                                           -> 'cgi'
#   2. AWS_LAMBDA_FUNCTION_NAME or LAMBDA_TASK_ROOT                -> 'lambda'
#   3. FUNCTION_TARGET, K_SERVICE, or GOOGLE_CLOUD_PROJECT         -> 'google_cloud_function'
#   4. AZURE_FUNCTIONS_ENVIRONMENT, FUNCTIONS_WORKER_RUNTIME, or
#      AzureWebJobsStorage                                         -> 'azure_function'
#   5. otherwise                                                   -> 'server'
#
# The companion helper SignalWire::Utils.is_serverless_mode lives in
# lib/signalwire/utils/serverless.rb.

module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # LoggingConfig — deployment-environment detection and the log-injection
    # control-character scrub.
    module LoggingConfig
      module_function

      # Detect the SDK's deployment environment based on well-known
      # environment variables.
      #
      # @return [String] one of 'cgi', 'lambda', 'google_cloud_function',
      #   'azure_function', or 'server'.
      def get_execution_mode
        return 'cgi' if env_set?('GATEWAY_INTERFACE')
        return 'lambda' if lambda_env?
        return 'google_cloud_function' if google_cloud_function_env?
        return 'azure_function' if azure_function_env?

        'server'
      end

      # @api private — whether AWS Lambda's marker variables are present.
      #
      # @return [Boolean]
      def lambda_env?
        env_set?('AWS_LAMBDA_FUNCTION_NAME') || env_set?('LAMBDA_TASK_ROOT')
      end
      private_class_method :lambda_env?

      # @api private — whether Google Cloud Functions / Cloud Run marker variables
      # are present.
      #
      # @return [Boolean]
      def google_cloud_function_env?
        env_set?('FUNCTION_TARGET') ||
          env_set?('K_SERVICE') ||
          env_set?('GOOGLE_CLOUD_PROJECT')
      end
      private_class_method :google_cloud_function_env?

      # @api private — whether Azure Functions marker variables are present.
      #
      # @return [Boolean]
      def azure_function_env?
        env_set?('AZURE_FUNCTIONS_ENVIRONMENT') ||
          env_set?('FUNCTIONS_WORKER_RUNTIME') ||
          env_set?('AzureWebJobsStorage')
      end
      private_class_method :azure_function_env?

      # @api private — whether an environment variable is set to a non-empty value.
      # An empty string counts as unset, so `FOO=` does not trigger a detection.
      #
      # @return [Boolean]
      def env_set?(name)
        v = ENV.fetch(name, nil)
        !v.nil? && !v.empty?
      end
      private_class_method :env_set?

      # Control characters that could be used for log injection: the C0/C1
      # controls minus \t, \n and \r.
      CONTROL_CHAR_RE = Regexp.new("[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]")

      # Strip control characters from every string value of a log event hash,
      # preventing log-injection. A plain hash transformer: one hash in, the
      # same hash out.
      #
      # @param event_dict [Hash] the log event
      # @return [Hash] the same hash with string values sanitised
      def strip_control_chars(event_dict)
        event_dict.each do |key, value|
          event_dict[key] = value.gsub(CONTROL_CHAR_RE, '') if value.is_a?(String)
        end
        event_dict
      end

      # Configure the SDK logging system once, globally, based on the
      # SIGNALWIRE_LOG_MODE / SIGNALWIRE_LOG_LEVEL environment variables.
      # Idempotent — a second call is a no-op unless
      # reset_logging_configuration ran first.
      def configure_logging
        return if @logging_configured

        SignalWire::Logging.configure if SignalWire::Logging.respond_to?(:configure)
        @logging_configured = true
      end

      # Reset the one-time configuration guard so configure_logging can run
      # again (used when environment variables change after initial setup).
      def reset_logging_configuration
        @logging_configured = false
        SignalWire::Logging.reset! if SignalWire::Logging.respond_to?(:reset!)
        nil
      end

      # Return a named logger: ensures logging is configured, then returns a
      # logger bound to +name+.
      #
      # @param name [String] the logger name
      # @return [Object] a logger instance
      def get_logger(name)
        configure_logging
        SignalWire::Logging.logger(name)
      end
    end
  end
end
