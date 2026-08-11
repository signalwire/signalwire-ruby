# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require_relative '../swaig/function_result'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Fluent builder for server-side DataMap tools.
  #
  # DataMap tools execute on SignalWire servers without requiring webhook
  # endpoints. This class provides a chainable API for building data_map
  # configurations that become SWAIG function definitions.
  #
  # All mutator methods return +self+ so calls can be chained:
  #
  #   dm = DataMap.new('get_weather')
  #        .purpose('Get current weather')
  #        .parameter('location', 'string', 'City name', required: true)
  #        .webhook('GET', 'https://api.weather.com/v1/current?q=${location}')
  #        .output(Swaig::FunctionResult.new('Weather: ${response.current.temp_f}F'))
  #
  class DataMap
    attr_reader :function_name

    # @param function_name [String] the SWAIG function name this DataMap defines
    def initialize(function_name)
      @function_name = function_name
      @purpose_text = ''
      @parameters = {} # name => { "type" => ..., "description" => ... }
      @required_params = []
      @expressions = []
      @webhooks = []
      @fallback_output = nil
      @global_error_keys = []
    end

    # Set the LLM-facing tool description (a.k.a. "purpose"). *PROMPT
    # ENGINEERING*, not developer documentation.
    #
    # The description string is rendered into the OpenAI tool schema
    # +description+ field on every LLM turn. The model reads it to
    # decide WHEN to call this tool. A vague +purpose+ is the #1 cause
    # of "the model has the right tool but doesn't call it" failures
    # with data-map tools.
    #
    # == Bad vs good
    #
    #   BAD : .purpose("weather api")
    #   GOOD: .purpose("Get the current weather conditions and "      \
    #                  "forecast for a specific city. Use this "        \
    #                  "whenever the user asks about weather, "         \
    #                  "temperature, rain, or similar conditions in a " \
    #                  "named location.")
    def purpose(desc)
      @purpose_text = desc
      self
    end

    # Alias for +purpose+. Sets the LLM-facing tool description. This
    # string is read by the model to decide WHEN to call this tool.
    # See +purpose+ for bad-vs-good examples.
    def description(desc)
      purpose(desc)
    end

    # Add a typed parameter to the function signature — the +desc+ is
    # LLM-FACING.
    #
    # Each parameter description is rendered into the OpenAI tool
    # schema under +parameters.properties.<name>.description+ and sent
    # to the model. The model uses it to decide HOW to fill in the
    # argument from user speech. It is prompt engineering, not
    # developer FYI.
    #
    # == Bad vs good
    #
    #   BAD : .parameter("city", "string", "the city")
    #   GOOD: .parameter("city", "string",
    #             "The name of the city to get weather for, e.g. "   \
    #             "'San Francisco'. Ask the user if they did not "    \
    #             "provide one. Include the state or country if the " \
    #             "city name is ambiguous.")
    #
    # @param name [String]
    # @param type [String] JSON-Schema type (string, number, boolean, array, object)
    # @param desc [String] LLM-facing prompt-engineering description
    #   telling the model how to extract this value from the user's
    #   utterance
    # @param required [Boolean] whether the parameter is required
    # @param enum [Array<String>, nil] optional list of allowed values
    def parameter(name, type, desc, required: false, enum: nil)
      param_def = { 'type' => type, 'description' => desc }
      param_def['enum'] = enum if enum && !enum.empty?
      @parameters[name] = param_def
      @required_params << name if required && !@required_params.include?(name)
      self
    end

    # Add an expression (pattern-matching rule).
    #
    # @param test_value [String] template string to test, e.g. "${args.command}"
    # @param pattern [String, Regexp] regex pattern to match against
    # @param output [Swaig::FunctionResult, Hash] result when pattern matches
    # @param nomatch_output [Swaig::FunctionResult, Hash, nil] result when pattern does not match
    def expression(test_value, pattern, output, nomatch_output: nil)
      pattern_str = pattern.is_a?(Regexp) ? pattern.source : pattern.to_s
      expr_def = {
        'string' => test_value,
        'pattern' => pattern_str,
        'output' => to_h_if_possible(output)
      }
      expr_def['nomatch-output'] = to_h_if_possible(nomatch_output) if nomatch_output
      @expressions << expr_def
      self
    end

    # Add a webhook (HTTP call) to the data_map pipeline.
    #
    # @param method [String] HTTP method (GET, POST, PUT, DELETE, etc.)
    # @param url [String] endpoint URL (may contain ${variable} substitutions)
    # @param headers [Hash, nil] optional HTTP headers
    # @param form_param [String, nil] send JSON body as a single form parameter
    # @param input_args_as_params [Boolean] merge function arguments into params
    # @param require_args [Array<String>, nil] only execute when these args are present
    def webhook(method, url, headers: nil, form_param: nil, input_args_as_params: false, require_args: nil)
      wh = {
        'url' => url,
        'method' => method.upcase
      }
      wh['headers']              = headers           if headers
      wh['form_param']           = form_param        if form_param
      wh['input_args_as_params'] = true               if input_args_as_params
      wh['require_args']         = require_args       if require_args
      @webhooks << wh
      self
    end

    # Add expressions to run after the most-recently-added webhook completes.
    def webhook_expressions(expressions)
      raise ArgumentError, 'Must add webhook before setting webhook expressions' if @webhooks.empty?

      @webhooks.last['expressions'] = expressions
      self
    end

    # Set request params for the most-recently-added webhook.
    #
    # This is the method for POST/PUT request data. It writes the +params+
    # webhook key, which schema.json +$defs/Webhook+ lists among its ten
    # permitted properties and which the engine's webhook readers look up. The
    # former +body+ builder wrote a +body+ key that the schema forbids and no
    # engine reader consumes — it was removed 2026-07-29; use this instead.
    def params(data)
      raise ArgumentError, 'Must add webhook before setting params' if @webhooks.empty?

      @webhooks.last['params'] = data
      self
    end

    # Configure array processing on the most-recently-added webhook response.
    #
    # @param config [Hash] must include keys: input_key, output_key, append. Optional: max.
    def foreach(config)
      raise ArgumentError, 'Must add webhook before setting foreach' if @webhooks.empty?
      raise ArgumentError, 'foreach config must be a Hash' unless config.is_a?(Hash)

      required_keys = %w[input_key output_key append]
      missing = required_keys - config.keys.map(&:to_s)
      raise ArgumentError, "foreach config missing required keys: #{missing.inspect}" unless missing.empty?

      @webhooks.last['foreach'] = config
      self
    end

    # Set the output result for the most-recently-added webhook.
    #
    # @param result [Swaig::FunctionResult, Hash]
    def output(result)
      raise ArgumentError, 'Must add webhook before setting output' if @webhooks.empty?

      @webhooks.last['output'] = to_h_if_possible(result)
      self
    end

    # Set a fallback output used when all webhooks fail.
    #
    # @param result [Swaig::FunctionResult, Hash]
    def fallback_output(result)
      @fallback_output = to_h_if_possible(result)
      self
    end

    # Set error keys on the most-recently-added webhook, or at the top level
    # if no webhook has been added yet.
    def error_keys(keys)
      if @webhooks.any?
        @webhooks.last['error_keys'] = keys
      else
        @global_error_keys = keys
      end
      self
    end

    # Set top-level error keys (applies to all webhooks).
    def global_error_keys(keys)
      @global_error_keys = keys
      self
    end

    # Serialize this DataMap into a complete SWAIG function definition Hash.
    #
    # @return [Hash] with keys: "function", "description", "parameters", "data_map"
    def to_swaig_function
      {
        'function' => @function_name,
        'description' => @purpose_text.empty? ? "Execute #{@function_name}" : @purpose_text,
        'parameters' => build_param_schema,
        'data_map' => build_data_map
      }
    end

    # ----------------------------------------------------------------
    # Class-level convenience constructors
    # ----------------------------------------------------------------

    # Build a simple API-calling tool in one shot.
    #
    # @param name [String]
    # @param url [String]
    # @param response_template [String]
    # @param parameters [Hash, nil] name => { "type" => ..., "description" => ..., "required" => bool }
    # @param method [String] HTTP method (default GET)
    # @param headers [Hash, nil]
    # @param error_keys [Array<String>, nil]
    # @return [DataMap]
    def self.create_simple_api_tool(name:, url:, response_template:, parameters: nil,
                                    method: 'GET', headers: nil, error_keys: nil)
      dm = new(name)
      add_parameters(dm, parameters)
      dm.webhook(method, url, headers: headers)
      dm.error_keys(error_keys) if error_keys
      dm.output(Swaig::FunctionResult.new(response_template))
      dm
    end

    # Build an expression-only tool (no HTTP calls).
    #
    # @param name [String]
    # @param patterns [Hash] test_value => [pattern, Swaig::FunctionResult]
    # @param parameters [Hash, nil] same format as +create_simple_api_tool+
    # @return [DataMap]
    def self.create_expression_tool(name:, patterns:, parameters: nil)
      dm = new(name)
      add_parameters(dm, parameters)
      patterns.each do |test_value, (pattern, result)|
        dm.expression(test_value, pattern, result)
      end
      dm
    end

    # Apply a parameters Hash (name => {type, description, required}) to +dm+.
    def self.add_parameters(builder, parameters)
      parameters&.each do |pname, pdef|
        builder.parameter(
          pname,
          pdef.fetch('type', 'string'),
          pdef.fetch('description', "#{pname} parameter"),
          required: pdef.fetch('required', false)
        )
      end
    end
    private_class_method :add_parameters

    private

    # @api private — convert a value to a Hash when it can be (a FunctionResult
    # typically), else pass it through, so both typed builders and raw Hashes can
    # be used as outputs.
    def to_h_if_possible(value)
      value.respond_to?(:to_h) ? value.to_h : value
    end

    # @api private — the tool's JSON Schema from the declared parameters, adding
    # `required` only when at least one parameter was marked required. No
    # parameters yields an empty object schema.
    #
    # @return [Hash]
    def build_param_schema
      return { 'type' => 'object', 'properties' => {} } unless @parameters.any?

      schema = { 'type' => 'object', 'properties' => @parameters.dup }
      schema['required'] = @required_params.dup if @required_params.any?
      schema
    end

    # @api private — the `data_map` object: expressions, webhooks, the fallback
    # output and the global error keys, each included only when non-empty.
    #
    # @return [Hash]
    def build_data_map
      data_map = {}
      data_map['expressions'] = @expressions          if @expressions.any?
      data_map['webhooks']    = @webhooks             if @webhooks.any?
      data_map['output']      = @fallback_output      if @fallback_output
      data_map['error_keys']  = @global_error_keys    if @global_error_keys.any?
      data_map
    end
  end
end
