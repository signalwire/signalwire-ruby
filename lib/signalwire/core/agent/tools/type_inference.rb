# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Reflection-based schema inference for SWAIG tool functions.

module SignalWire
  # Core — internal building blocks shared by the agent, SWML and SWAIG layers.
  module Core
    # Agent — the agent internals: prompt management and tool registration.
    module Agent
      # Tools — SWAIG tool registration and parameter type inference.
      module Tools
        # Infer a JSON Schema for a SWAIG tool's parameters from a Ruby
        # callable's signature, and wrap a typed handler so it can be
        # invoked with the standard SWAIG calling convention.
        #
        # Ruby has no static type annotations, so the schema is inferred
        # from the callable's parameter list via reflection
        # (``Method#parameters`` / ``Proc#parameters``). Each keyword or
        # positional parameter becomes a ``string`` property; a parameter
        # with a default (``:opt`` / ``:key``) is optional, one without
        # (``:req`` / ``:keyreq``) is required. An explicit
        # ``types:`` map lets callers refine the JSON-Schema ``type`` per
        # parameter when they know it.
        module TypeInference
          module_function

          # Map a Ruby class to its JSON Schema type name.
          RUBY_TYPE_MAP = {
            'String' => 'string',
            'Integer' => 'integer',
            'Float' => 'number',
            'Numeric' => 'number',
            'TrueClass' => 'boolean',
            'FalseClass' => 'boolean',
            'Array' => 'array',
            'Hash' => 'object'
          }.freeze

          # Inspect a callable's signature to infer a JSON Schema for
          # SWAIG tool parameters.
          #
          # A parameter named ``:raw_data`` is treated as the SWAIG
          # raw-payload channel and excluded from the schema.
          #
          # @param func [Method, Proc] the callable to inspect
          # @param types [Hash{Symbol,String => Class,String}, nil]
          #   optional per-parameter JSON-Schema-type overrides. Values may
          #   be a Ruby class (``Integer``) or a schema type
          #   string (``"integer"``).
          # @param descriptions [Hash{Symbol,String => String}, nil]
          #   optional per-parameter descriptions.
          # @return [Array(Hash, Array<String>, String, nil, Boolean, Boolean)]
          #   ``[parameters, required, description, is_typed, has_raw_data]``:
          #   - parameters: name => property Hash (string keys)
          #   - required: required parameter names
          #   - description: always nil (there is no comment text to introspect
          #     at runtime; pass +descriptions:+ to supply one)
          #   - is_typed: true if the callable takes named parameters
          #     (i.e. it is NOT the old-style ``(args, raw_data)`` handler)
          #   - has_raw_data: true if the callable accepts ``raw_data``
          def infer_schema(func, types: nil, descriptions: nil)
            params = callable_parameters(func)
            names = params.map { |_kind, name| name }

            # Old-style handler: (args) or (args, raw_data) with no typing.
            return [{}, [], nil, false, false] if legacy_handler?(names)

            has_raw_data = names.include?(:raw_data)
            schema_params = params.reject { |_kind, name| name == :raw_data }

            build_schema(schema_params, types || {}, descriptions || {}, has_raw_data)
          end

          # Wrap a typed handler so it can be invoked with the standard
          # SWAIG calling convention ``(args, raw_data)``.
          #
          # The wrapper explodes the +args+ Hash into keyword arguments for
          # the wrapped callable, passing +raw_data+ as a keyword only when
          # the handler declared it.
          #
          # @param func [Method, Proc] the typed handler
          # @param has_raw_data [Boolean] pass raw_data as a keyword
          # @return [Proc] a Proc with the ``(args, raw_data)`` signature
          def create_typed_handler_wrapper(func, has_raw_data)
            lambda do |args, raw_data|
              kwargs = symbolize_args(args)
              if has_raw_data
                func.call(**kwargs, raw_data: raw_data)
              else
                func.call(**kwargs)
              end
            end
          end

          # Reflect the callable's parameters as [kind, name] pairs,
          # dropping the block parameter and any unnamed splat.
          def callable_parameters(func)
            func.parameters.reject do |kind, name|
              name.nil? || kind == :block
            end
          end

          # An old-style handler is the positional ``(args)`` or
          # ``(args, raw_data)`` shape with no additional named params.
          def legacy_handler?(names)
            [[:args], %i[args raw_data]].include?(names)
          end

          # Parameter kinds that indicate a splat (``*rest`` / ``**keyrest``).
          SPLAT_KINDS = %i[rest keyrest].freeze

          # A callable with a splat (``*rest`` / ``**keyrest``) can't be
          # introspected into a fixed schema — fall back to old style.
          def splat_present?(params)
            params.any? { |kind, _name| SPLAT_KINDS.include?(kind) }
          end

          # Build the (parameters, required, ...) tuple from named params.
          def build_schema(schema_params, types, descriptions, has_raw_data)
            return [{}, [], nil, false, false] if splat_present?(schema_params)
            return [{}, [], nil, true, has_raw_data] if schema_params.empty?

            parameters = {}
            required = []
            schema_params.each do |kind, name|
              key = name.to_s
              parameters[key] = property_for(name, types, descriptions)
              required << key if required_kind?(kind)
            end
            [parameters, required, nil, true, has_raw_data]
          end

          # Build one JSON-Schema property Hash for a parameter.
          def property_for(name, types, descriptions)
            prop = { 'type' => schema_type(types[name] || types[name.to_s]) }
            desc = descriptions[name] || descriptions[name.to_s]
            prop['description'] = desc if desc
            prop
          end

          # Resolve a type override (Class or schema-type string) to a JSON
          # Schema type name; default to "string" when unknown/absent.
          def schema_type(override)
            return 'string' if override.nil?
            return override if override.is_a?(String) && RUBY_TYPE_MAP.value?(override)

            RUBY_TYPE_MAP.fetch(override.to_s, 'string')
          end

          # Required kinds: :req (positional, no default) and :keyreq
          # (keyword, no default). :opt / :key have defaults → optional.
          def required_kind?(kind)
            %i[req keyreq].include?(kind)
          end

          # Convert an args Hash (string or symbol keys) into symbol-keyed
          # keyword arguments for the wrapped handler.
          def symbolize_args(args)
            return {} unless args.is_a?(Hash)

            args.each_with_object({}) { |(k, v), acc| acc[k.to_sym] = v }
          end

          # Internal helpers — only infer_schema and
          # create_typed_handler_wrapper are public.
          private_class_method :callable_parameters, :legacy_handler?,
                               :splat_present?, :build_schema, :property_for,
                               :schema_type, :required_kind?, :symbolize_args
        end
      end
    end
  end
end
