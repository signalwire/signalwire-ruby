# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

module SignalWire
  module Utils
    # SchemaValidationError — Ruby port of
    # signalwire.utils.schema_utils.SchemaValidationError.
    #
    # Raised when SWML schema validation of a verb config fails.
    class SchemaValidationError < StandardError
      attr_reader :verb_name, :errors

      # Construct a SchemaValidationError. Mirrors Python's
      # SchemaValidationError(verb_name, errors).
      def initialize(verb_name, errors)
        @verb_name = verb_name
        @errors = errors || []
        message = "Schema validation failed for '#{verb_name}': #{@errors.join('; ')}"
        super(message)
      end
    end

    # SchemaUtils — Ruby port of signalwire.utils.schema_utils.SchemaUtils.
    #
    # Loads the SWML JSON Schema, extracts verb metadata, and validates
    # either a single verb config or a complete SWML document.
    #
    # Construction rules mirror Python:
    #   - Pass schema_path: nil to use the bundled schema.json.
    #   - schema_validation: false disables validation (validate_verb returns
    #     true for every call).
    #   - The env var SWML_SKIP_SCHEMA_VALIDATION=1/true/yes also disables
    #     validation regardless of the constructor argument.
    #
    # The Ruby port currently ships only the lightweight validator (verb
    # existence + required-property check). Full JSON Schema validation
    # can be wired in via the `json_schemer` gem by extending
    # init_full_validator. The lightweight contract matches Python's
    # _validate_verb_lightweight() exactly.
    class SchemaUtils
      # @return [Hash{String=>Object}] parsed JSON Schema document
      attr_reader :schema

      # @return [String, nil] resolved schema path (nil = embedded default)
      attr_reader :schema_path

      # Construct a SchemaUtils.
      #
      # @param schema_path [String, nil] path to a schema.json file; nil for
      #   the bundled copy at lib/signalwire/swml/schema.json.
      # @param schema_validation [Boolean] enable/disable schema validation.
      def initialize(schema_path = nil, schema_validation = true)
        env_skip = env_boolish(ENV.fetch('SWML_SKIP_SCHEMA_VALIDATION', ''))
        @schema_path = schema_path
        @validation_enabled = schema_validation && !env_skip
        @schema = load_schema
        @verbs = {}
        extract_verbs
        init_full_validator if @validation_enabled && !@schema.empty?
      end

      # Whether full JSON Schema validation is wired up.
      # Mirrors Python's full_validation_available property.
      def full_validation_available?
        !@full_validator.nil?
      end

      # Read and parse the JSON Schema. Mirrors Python's load_schema().
      def load_schema
        path = @schema_path || default_schema_path
        return {} if path.nil? || !File.exist?(path)

        raw = File.read(path, encoding: 'UTF-8')
        JSON.parse(raw)
      rescue JSON::ParserError, Errno::ENOENT
        {}
      end

      # Sorted list of all known verb names.
      # Mirrors Python's get_all_verb_names().
      def get_all_verb_names
        @verbs.keys.sort
      end

      # The properties[verb_name] block for a verb, or {} when unknown.
      # Mirrors Python's get_verb_properties(verb_name).
      def get_verb_properties(verb_name)
        v = @verbs[verb_name]
        return {} if v.nil?

        outer_props = v['definition']['properties'] rescue nil
        return {} unless outer_props.is_a?(Hash)

        inner = outer_props[verb_name]
        return {} unless inner.is_a?(Hash)

        inner
      end

      # The required list for a verb, or [] when unknown / no required.
      # Mirrors Python's get_verb_required_properties(verb_name).
      def get_verb_required_properties(verb_name)
        inner = get_verb_properties(verb_name)
        req = inner['required']
        return [] unless req.is_a?(Array)

        req.select { |x| x.is_a?(String) }
      end

      # Parameter-definition block used by code-gen tooling.
      # Mirrors Python's get_verb_parameters(verb_name).
      def get_verb_parameters(verb_name)
        inner = get_verb_properties(verb_name)
        props = inner['properties']
        return {} unless props.is_a?(Hash)

        props
      end

      # Validate a verb config against the schema.
      # Mirrors Python's validate_verb(verb_name, verb_config).
      #
      # @return [Array(Boolean, Array<String>)] (valid, errors) tuple.
      def validate_verb(verb_name, verb_config)
        return [true, []] unless @validation_enabled

        unless @verbs.key?(verb_name)
          return [false, ["Unknown verb: #{verb_name}"]]
        end

        if @full_validator
          validate_verb_full(verb_name, verb_config)
        else
          validate_verb_lightweight(verb_name, verb_config)
        end
      end

      # Validate a complete SWML document.
      # Mirrors Python's validate_document(document). Returns
      # (false, ['Schema validator not initialized']) when no full
      # validator is wired in.
      def validate_document(document)
        if @full_validator.nil?
          return [false, ['Schema validator not initialized']]
        end

        # Reserved for full-validator wiring.
        [true, []]
      end

      # Generate a Python-style method signature string for a verb.
      # Mirrors Python's generate_method_signature(verb_name).
      def generate_method_signature(verb_name)
        params = get_verb_parameters(verb_name)
        required = get_verb_required_properties(verb_name).to_set
        parts = ['self']
        keys = params.keys.sort
        keys.each do |name|
          t = python_type_annotation(params[name])
          parts << if required.include?(name)
                     "#{name}: #{t}"
                   else
                     "#{name}: Optional[#{t}] = None"
                   end
        end
        parts << '**kwargs'
        doc = +"\"\"\"\n        Add the #{verb_name} verb to the current document\n        \n"
        keys.each do |name|
          desc = ''
          d = params[name]
          if d.is_a?(Hash) && d['description']
            desc = d['description'].to_s.gsub("\n", ' ').strip
          end
          doc << "        Args:\n            #{name}: #{desc}\n"
        end
        doc << "        \n        Returns:\n            True if the verb was added successfully, False otherwise\n        \"\"\"\n"
        "def #{verb_name}(#{parts.join(', ')}) -> bool:\n#{doc}"
      end

      # Generate a Python-style method body string for a verb.
      # Mirrors Python's generate_method_body(verb_name).
      def generate_method_body(verb_name)
        params = get_verb_parameters(verb_name)
        keys = params.keys.sort
        lines = [
          '        # Prepare the configuration',
          '        config = {}'
        ]
        keys.each do |name|
          lines << "        if #{name} is not None:"
          lines << "            config['#{name}'] = #{name}"
        end
        lines << '        # Add any additional parameters from kwargs'
        lines << '        for key, value in kwargs.items():'
        lines << '            if value is not None:'
        lines << '                config[key] = value'
        lines << ''
        lines << "        # Add the #{verb_name} verb"
        lines << "        return self.add_verb('#{verb_name}', config)"
        lines.join("\n")
      end

      private

      def default_schema_path
        # Bundled schema lives in lib/signalwire/swml/schema.json
        File.expand_path('../swml/schema.json', __dir__)
      end

      def env_boolish(value)
        %w[1 true yes].include?(value.to_s.strip.downcase)
      end

      def extract_verbs
        defs = @schema['$defs']
        return unless defs.is_a?(Hash)

        swml_method = defs['SWMLMethod']
        return unless swml_method.is_a?(Hash)

        any_of = swml_method['anyOf']
        return unless any_of.is_a?(Array)

        any_of.each do |entry|
          next unless entry.is_a?(Hash)

          ref = entry['$ref']
          next unless ref.is_a?(String)

          prefix = '#/$defs/'
          next unless ref.start_with?(prefix)

          schema_name = ref[prefix.length..]
          defn = defs[schema_name]
          next unless defn.is_a?(Hash)

          props = defn['properties']
          next unless props.is_a?(Hash) && !props.empty?

          actual_verb = props.keys.first
          @verbs[actual_verb] = {
            'name' => actual_verb,
            'schema_name' => schema_name,
            'definition' => defn
          }
        end
      end

      def init_full_validator
        # Reserved for full-validator wiring (json_schemer gem).
        @full_validator = nil
      end

      def validate_verb_full(verb_name, verb_config)
        # Reserved for full-validator wiring; falls back to lightweight check.
        validate_verb_lightweight(verb_name, verb_config)
      end

      def validate_verb_lightweight(verb_name, verb_config)
        errors = []
        get_verb_required_properties(verb_name).each do |prop|
          unless verb_config.key?(prop)
            errors << "Missing required property '#{prop}' for verb '#{verb_name}'"
          end
        end
        [errors.empty?, errors]
      end

      def python_type_annotation(defn)
        return 'Any' unless defn.is_a?(Hash)

        case defn['type']
        when 'string'  then 'str'
        when 'integer' then 'int'
        when 'number'  then 'float'
        when 'boolean' then 'bool'
        when 'array'
          item = 'Any'
          if defn['items'].is_a?(Hash)
            item = python_type_annotation(defn['items'])
          end
          "List[#{item}]"
        when 'object'  then 'Dict[str, Any]'
        else
          'Any'
        end
      end
    end
  end
end

require 'set'
