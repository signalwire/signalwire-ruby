# frozen_string_literal: true

require_relative '../core/logging_config'

# SignalWire::Utils.is_serverless_mode returns true when running inside any
# short-lived / event-driven environment (i.e. not 'server').

module SignalWire
  # Utils — small shared helpers with no dependency on the agent surface.
  module Utils
    module_function

    # @return [Boolean] true unless the detected mode is 'server'.
    # @!visibility private  (idiomatic alias: #serverless?; original name
    #   kept for back-compat)
    def is_serverless_mode
      SignalWire::Core::LoggingConfig.get_execution_mode != 'server'
    end

    # Idiomatic Ruby `?`-predicate alias of is_serverless_mode.
    alias serverless? is_serverless_mode
  end
end
