# frozen_string_literal: true

# Cross-language SDK contract for serverless / deployment-mode detection.
#
# Mirrors signalwire.core.logging_config.get_execution_mode in the Python
# reference. Order of precedence (FIRST match wins):
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
  module Core
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

      def lambda_env?
        env_set?('AWS_LAMBDA_FUNCTION_NAME') || env_set?('LAMBDA_TASK_ROOT')
      end
      private_class_method :lambda_env?

      def google_cloud_function_env?
        env_set?('FUNCTION_TARGET') ||
          env_set?('K_SERVICE') ||
          env_set?('GOOGLE_CLOUD_PROJECT')
      end
      private_class_method :google_cloud_function_env?

      def azure_function_env?
        env_set?('AZURE_FUNCTIONS_ENVIRONMENT') ||
          env_set?('FUNCTIONS_WORKER_RUNTIME') ||
          env_set?('AzureWebJobsStorage')
      end
      private_class_method :azure_function_env?

      def env_set?(name)
        v = ENV.fetch(name, nil)
        !v.nil? && !v.empty?
      end
      private_class_method :env_set?
    end
  end
end
