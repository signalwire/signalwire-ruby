# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# SWAIGFunction class for defining and managing SWAIG function interfaces.
#
# A SWAIGFunction is exactly the same concept as a "tool" in native
# OpenAI / Anthropic tool calling: it holds a
# name/description/parameters/handler and renders into the tool schema sent to
# the model.

require_relative 'function_result'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Swaig — the SWAIG function-call surface: results, actions and typed payloads.
  module Swaig
    # Represents a SWAIG function — a tool the AI model can call.
    class SWAIGFunction
      attr_reader :name, :handler, :description, :parameters, :secure, :fillers,
                  :wait_file, :wait_file_loops, :webhook_url, :required,
                  :is_typed_handler, :extra_swaig_fields, :is_external

      # JSON-Schema type -> predicate, used by the built-in validator fallback.
      JSON_TYPE_CHECKS = {
        'string' => ->(v) { v.is_a?(String) },
        'integer' => ->(v) { v.is_a?(Integer) },
        'number' => ->(v) { v.is_a?(Numeric) },
        'boolean' => ->(v) { [true, false].include?(v) },
        'array' => ->(v) { v.is_a?(Array) },
        'object' => ->(v) { v.is_a?(Hash) }
      }.freeze

      # Generic, non-leaking message returned when a handler raises.
      EXECUTE_ERROR_RESPONSE =
        "Sorry, I couldn't complete that action. Please try again or contact support if the issue persists."

      # Initialize a new SWAIG function.
      #
      # @param name [String] function name (the +name+ field in the tool schema)
      # @param handler [#call] callable invoked when the model calls this tool
      # @param description [String] LLM-facing description
      # @param parameters [Hash, nil] JSON Schema for the arguments
      # @param secure [Boolean] whether this function requires SWAIG token validation
      # @param fillers [Hash, nil] filler phrases by language code (deprecated)
      # @param wait_file [String, nil] audio file URL to play while executing
      # @param wait_file_loops [Integer, nil] number of times to loop wait_file
      # @param webhook_url [String, nil] external webhook URL instead of local handling
      # @param required [Array<String>, nil] required parameter names
      # @param is_typed_handler [Boolean] whether the handler uses type-hinted parameters
      # @param extra_swaig_fields [Hash] additional SWAIG-only fields (meta_data_token, etc.)
      def initialize(name:, handler:, description:, parameters: nil, secure: false,
                     fillers: nil, wait_file: nil, wait_file_loops: nil, webhook_url: nil,
                     required: nil, is_typed_handler: false, **extra_swaig_fields)
        {
          name: name, handler: handler, description: description, secure: secure,
          fillers: fillers, wait_file: wait_file, wait_file_loops: wait_file_loops,
          webhook_url: webhook_url, is_typed_handler: is_typed_handler,
          parameters: parameters || {}, required: required || []
        }.each { |k, v| instance_variable_set("@#{k}", v) }
        @extra_swaig_fields = extra_swaig_fields.transform_keys(&:to_s)
        @is_external = !webhook_url.nil? # external when a webhook_url is provided
      end

      # Call the underlying handler function.
      #
      # +function.call(args, raw_data)+ invokes the handler.
      #
      # @return [Object] the handler's return value
      def call(*, **)
        @handler.call(*, **)
      end

      # Execute the function with the given arguments.
      #
      # Everything must end up as a FunctionResult Hash. On any error a generic
      # error message is returned (details are logged, not exposed to the AI).
      #
      # @param args [Hash] parsed arguments for the function
      # @param raw_data [Hash, nil] optional raw request data
      # @return [Hash] function result as a Hash (from FunctionResult#to_h)
      def execute(args, raw_data = nil)
        coerce_result(@handler.call(args, raw_data || {}))
      rescue StandardError => e
        SignalWire::Logging.logger("SWAIG::#{@name}").error("Error executing SWAIG function #{@name}: #{e}")
        FunctionResult.new(EXECUTE_ERROR_RESPONSE).to_h
      end

      # Validate the arguments against the parameter schema.
      #
      # Uses the json-schema gem for full JSON-Schema validation when it is
      # installed; otherwise falls back to a lightweight built-in check of the
      # +required+ list and each property's +type+. The full validator is
      # optional, so a minimal always-available check keeps basic validation
      # working when the gem is absent.
      #
      # @param args [Hash] arguments to validate
      # @return [Array(Boolean, Array<String>)] (is_valid, errors)
      def validate_args(args)
        schema = ensure_parameter_structure
        return [true, []] if schema.nil? || schema['properties'].nil? || schema['properties'].empty?

        validate_against_schema(schema, args)
      rescue StandardError => e
        SignalWire::Logging.logger("SWAIG::#{@name}").debug("json-schema validation error for #{@name}: #{e}")
        [true, []]
      end

      # Convert this function to a SWAIG-compatible Hash for SWML.
      #
      # @param base_url [String] base URL for the webhook
      # @param token [String, nil] optional auth token to include
      # @param call_id [String, nil] optional call ID for session tracking
      # @param include_auth [Boolean] whether to include auth credentials in the URL
      # @return [Hash] representation for the SWAIG array in SWML
      def to_swaig(base_url:, token: nil, call_id: nil, include_auth: true) # rubocop:disable Lint/UnusedMethodArgument
        # All functions use a single /swaig endpoint.
        url = "#{base_url}/swaig"
        url = "#{url}?token=#{token}&call_id=#{call_id}" if token && call_id

        function_def = {
          'function' => @name,
          'description' => @description,
          'parameters' => ensure_parameter_structure
        }
        function_def['web_hook_url'] = url unless url.nil? || url.empty?
        function_def['fillers'] = @fillers if @fillers && !@fillers.empty?
        function_def.merge!(@extra_swaig_fields)
      end

      private

      # Validate against +schema+ using the json-schema gem when installed,
      # else the built-in fallback (the full validator is optional).
      def validate_against_schema(schema, args)
        require 'json-schema'
        errors = JSON::Validator.fully_validate(schema, args)
        [errors.empty?, errors]
      rescue LoadError
        validate_args_builtin(schema, args)
      end

      # Coerce a handler return value into a FunctionResult Hash.
      def coerce_result(result)
        return result.to_h if result.is_a?(FunctionResult)
        return result if result.is_a?(Hash) && result.key?('response')
        return FunctionResult.new('Function completed successfully').to_h if result.is_a?(Hash)

        FunctionResult.new(result.to_s).to_h
      end

      # Minimal built-in argument validation used when no JSON-Schema gem is
      # installed: enforces the schema's +required+ list and each declared
      # property's JSON +type+. Returns (is_valid, errors).
      def validate_args_builtin(schema, args)
        args = {} unless args.is_a?(Hash)
        errors = missing_required_errors(schema, args)
        errors.concat(type_mismatch_errors(schema, args))
        [errors.empty?, errors]
      end

      # Errors for any required property absent from the args.
      def missing_required_errors(schema, args)
        Array(schema['required']).filter_map do |name|
          "missing required property '#{name}'" unless arg_present?(args, name)
        end
      end

      # Errors for any present property whose value fails its declared type.
      def type_mismatch_errors(schema, args)
        (schema['properties'] || {}).filter_map do |name, prop|
          next unless prop.is_a?(Hash) && arg_present?(args, name)

          checker = JSON_TYPE_CHECKS[prop['type']]
          "property '#{name}' must be of type #{prop['type']}" if checker && !checker.call(arg_value(args, name))
        end
      end

      # Whether +name+ (string or symbol key) is present in the args hash.
      def arg_present?(args, name)
        args.key?(name) || args.key?(name.to_sym)
      end

      # The value for +name+ (string or symbol key) in the args hash.
      def arg_value(args, name)
        args.key?(name) ? args[name] : args[name.to_sym]
      end

      # Ensure the parameters are correctly structured for SWML — wrap loose
      # property maps in the +{type, properties[, required]}+ envelope.
      def ensure_parameter_structure
        return { 'type' => 'object', 'properties' => {} } if @parameters.nil? || @parameters.empty?

        return @parameters if @parameters.key?('type') && @parameters.key?('properties')

        result = { 'type' => 'object', 'properties' => @parameters }
        result['required'] = @required unless @required.empty?
        result
      end
    end
  end
end
