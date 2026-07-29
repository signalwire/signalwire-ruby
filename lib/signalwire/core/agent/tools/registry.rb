# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Tool registration and management.

module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # Agent — the agent internals: prompt management and tool registration.
    module Agent
      # Tools — SWAIG tool registration and parameter type inference.
      module Tools
        # Manages SWAIG function registration.
        #
        # Mirrors Python's
        # ``signalwire.core.agent.tools.registry.ToolRegistry`` and the
        # TypeScript ``ToolRegistry`` class. A registry holds SWAIG
        # function definitions keyed by name. Two kinds of entries are
        # supported:
        #
        # - definitions created via {#define_tool} (carry a +handler+), and
        # - raw SWAIG function dictionaries via {#register_swaig_function}
        #   (e.g. from a DataMap's ``to_swaig_function``) which execute on
        #   SignalWire's server and carry no handler.
        #
        # Ruby has no dedicated ``SWAIGFunction`` value object (AgentBase
        # stores plain Hashes on the wire), so the registry stores the
        # built definition Hash with string keys, matching the wire shape.
        class ToolRegistry
          # @return [Object, nil] the parent AgentBase back-reference this
          #   registry was constructed with. The reference exposes the same
          #   attribute (core/agent/tools/registry.py), so a caller that passes
          #   an agent can read it back.
          attr_reader :agent

          # @param agent [Object, nil] optional parent AgentBase instance
          #   (kept as a back-reference for parity with the Python/TS
          #   registries; may be nil for standalone use).
          def initialize(agent = nil)
            @agent = agent
            @swaig_functions = {} # name => definition Hash (string keys)
          end

          # Define a SWAIG function that the AI can call.
          #
          # Python parity:
          # ``define_tool(name, description, parameters, handler,
          # secure=True, fillers=None, wait_file=None, wait_file_loops=None,
          # webhook_url=None, required=None, is_typed_handler=False,
          # **swaig_fields)``.
          #
          # @param name [String] function name (must be unique)
          # @param description [String] LLM-facing description
          # @param parameters [Hash] JSON-Schema parameters
          # @param handler [Proc, nil] handler invoked when the tool runs
          # @param secure [Boolean] whether to require token validation
          # @param fillers [Hash, nil] language_code => [phrases]
          # @param wait_file [String, nil] audio URL played while running
          # @param wait_file_loops [Integer, nil] loop count for wait_file
          # @param webhook_url [String, nil] external webhook URL
          # @param required [Array<String>, nil] required parameter names
          # @param is_typed_handler [Boolean] handler uses typed params
          # @param swaig_fields [Hash, nil] extra fields merged into the def
          # @raise [ArgumentError] if the tool name already exists
          # @return [Hash] the stored definition
          # ``parameters:`` and ``handler:`` are REQUIRED, matching the reference
          # (``define_tool(name, description, parameters, handler, ...)``). A tool
          # with no parameters states ``parameters: {}`` explicitly.
          def define_tool(name:, description:, parameters:, handler:,
                          secure: true, fillers: nil,
                          wait_file: nil, wait_file_loops: nil,
                          webhook_url: nil, required: nil,
                          is_typed_handler: false, swaig_fields: nil)
            raise ArgumentError, "Tool with name '#{name}' already exists" if @swaig_functions.key?(name)

            definition = build_definition(
              name, description, parameters, required,
              handler: handler, secure: secure, fillers: fillers,
              wait_file: wait_file, wait_file_loops: wait_file_loops,
              webhook_url: webhook_url, is_typed_handler: is_typed_handler,
              swaig_fields: swaig_fields
            )
            @swaig_functions[name] = definition
          end

          # Register a raw SWAIG function dictionary (e.g. from a DataMap's
          # ``to_swaig_function``).
          #
          # Python parity: ``register_swaig_function(function_dict)`` —
          # requires a ``function`` field and rejects duplicates.
          #
          # @param function_dict [Hash] complete SWAIG function definition
          # @raise [ArgumentError] if the name is missing or already exists
          # @return [Hash] the stored definition (string keys)
          def register_swaig_function(function_dict)
            fname = function_dict['function'] || function_dict[:function]
            raise ArgumentError, "Function dictionary must contain 'function' field with the function name" unless fname
            raise ArgumentError, "Tool with name '#{fname}' already exists" if @swaig_functions.key?(fname)

            @swaig_functions[fname] = function_dict.transform_keys(&:to_s)
          end

          # Get a registered function by name.
          #
          # @param name [String] function name
          # @return [Hash, nil] the definition Hash, or nil if not found
          def get_function(name)
            @swaig_functions[name]
          end

          # Get a copy of all registered functions.
          #
          # @return [Hash{String => Hash}] name => definition Hash
          def get_all_functions
            @swaig_functions.dup
          end

          # Check whether a function is registered.
          #
          # @param name [String] function name
          # @return [Boolean] true if the function exists
          def has_function(name)
            @swaig_functions.key?(name)
          end

          # Remove a registered function.
          #
          # @param name [String] function name
          # @return [Boolean] true if removed, false if not found
          def remove_function(name)
            return false unless @swaig_functions.key?(name)

            @swaig_functions.delete(name)
            true
          end

          private

          # Build the wire-shape definition Hash for a defined tool. Optional
          # fields are only emitted when present so the wire matches
          # AgentBase's own tool serialisation.
          def build_definition(name, description, parameters, required, **opts)
            definition = {
              'function' => name,
              'description' => description,
              'parameters' => normalise_parameters(parameters, required)
            }
            apply_optional_fields(definition, opts)
            merge_swaig_fields(definition, opts[:swaig_fields])
            definition['handler'] = opts[:handler] unless opts[:handler].nil?
            definition['secure'] = opts[:secure]
            definition
          end

          # @api private — add the optional SWAIG fields that were supplied:
          # `fillers` (only when a non-empty Hash), `wait_file`, `wait_file_loops`,
          # `webhook_url`, and `is_typed_handler` only when true.
          def apply_optional_fields(definition, opts)
            definition['fillers'] = opts[:fillers] if opts[:fillers].is_a?(Hash) && !opts[:fillers].empty?
            %i[wait_file wait_file_loops webhook_url].each do |key|
              definition[key.to_s] = opts[key] if opts[key]
            end
            definition['is_typed_handler'] = true if opts[:is_typed_handler]
          end

          # @api private — merge caller-supplied extra SWAIG fields over the definition,
          # stringifying their keys. A non-Hash is ignored.
          def merge_swaig_fields(definition, swaig_fields)
            return unless swaig_fields.is_a?(Hash)

            swaig_fields.each { |k, v| definition[k.to_s] = v }
          end

          # Wrap bare properties in an object schema and inject +required+.
          def normalise_parameters(parameters, required)
            schema = object_schema(parameters)
            return schema unless required.is_a?(Array) && !required.empty?

            existing = schema['required'] || []
            schema.merge('required' => (existing + required).uniq)
          end

          # @api private — a schema that already declares `type: object` passes through;
          # a bare property map is wrapped as `{type: object, properties: …}`, and nil
          # becomes an empty object schema.
          #
          # @return [Hash]
          def object_schema(parameters)
            return parameters if parameters.is_a?(Hash) && parameters['type'] == 'object'

            { 'type' => 'object', 'properties' => parameters || {} }
          end
        end
      end
    end
  end
end
