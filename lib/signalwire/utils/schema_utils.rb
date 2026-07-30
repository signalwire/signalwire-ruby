# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'
require_relative '../error'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Utils — small shared helpers with no dependency on the agent surface.
  module Utils
    # SchemaValidationError — Ruby port of
    # signalwire.utils.schema_utils.SchemaValidationError.
    #
    # Raised when SWML schema validation of a verb config fails.
    class SchemaValidationError < SignalWire::Error
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
    # Full JSON Schema validation (Draft 2020-12, including closed-key
    # `unevaluatedProperties` and type checking) is performed via the
    # `json_schemer` gem, mirroring Python's jsonschema-rs validator: a verb
    # config is wrapped in a minimal SWML document and validated against the
    # bundled schema.json. When json_schemer is unavailable the port falls back
    # to the lightweight validator (verb existence + required-property check),
    # which matches Python's _validate_verb_lightweight() exactly.
    class SchemaUtils
      # JSON-schema scalar type → Python type-annotation string (codegen).
      PYTHON_SCALAR_TYPES = {
        'string' => 'str', 'integer' => 'int', 'number' => 'float',
        'boolean' => 'bool', 'object' => 'Dict[str, Any]'
      }.freeze

      # Keywords stripped from a property whose value set is advisory, before
      # the full validator is built — the ones that pin it to a fixed set of
      # values. See {#apply_sdk_widen}.
      WIDEN_STRIPPED_KEYS = %w[anyOf oneOf enum const x-sdk-enum-literal].freeze

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
        @full_validator = nil
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

        outer_props = verb_definition_properties(v)
        return {} unless outer_props.is_a?(Hash)

        inner = outer_props[verb_name]
        inner.is_a?(Hash) ? inner : {}
      end

      # The required list for a verb, or [] when unknown / no required.
      # Mirrors Python's get_verb_required_properties(verb_name).
      def get_verb_required_properties(verb_name)
        inner = get_verb_properties(verb_name)
        req = inner['required']
        return [] unless req.is_a?(Array)

        req.grep(String)
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

        return [false, ["Unknown verb: #{verb_name}"]] unless @verbs.key?(verb_name)

        if @full_validator
          validate_verb_full(verb_name, verb_config)
        else
          validate_verb_lightweight(verb_name, verb_config)
        end
      end

      # Validate a complete SWML document against the full JSON Schema.
      # Mirrors Python's validate_document(document): runs the json_schemer
      # validator over the whole document. Returns
      # (false, ['Schema validator not initialized']) when no full validator is
      # wired in (validation disabled or json_schemer unavailable).
      def validate_document(document)
        return [false, ['Schema validator not initialized']] if @full_validator.nil?

        errors = @full_validator.validate(document).to_a
        return [true, []] if errors.empty?

        [false, ["Document validation error: #{schema_error_detail(nil, errors)}"]]
      end

      # Generate a Python-style method signature string for a verb.
      # Mirrors Python's generate_method_signature(verb_name).
      def generate_method_signature(verb_name)
        params = get_verb_parameters(verb_name)
        keys = params.keys.sort
        parts = signature_param_parts(verb_name, params, keys)
        doc = signature_docstring(verb_name, params, keys)
        "def #{verb_name}(#{parts.join(', ')}) -> bool:\n#{doc}"
      end

      # Generate a Python-style method body string for a verb.
      # Mirrors Python's generate_method_body(verb_name).
      def generate_method_body(verb_name)
        keys = get_verb_parameters(verb_name).keys.sort
        config_lines = keys.flat_map do |name|
          ["        if #{name} is not None:", "            config['#{name}'] = #{name}"]
        end
        ['        # Prepare the configuration', '        config = {}', *config_lines,
         *method_body_kwargs_lines(verb_name)].join("\n")
      end

      private

      # @api private — internal helper used by SWMLService for handler
      # verbs (not part of the reference SchemaUtils surface).
      # Top-level-key validation for a verb whose config is checked by a
      # specialized handler (e.g. the ai verb). Enforces exactly the closed-key
      # + required-key contract at the verb's OWN level — reject an unknown or
      # misspelled top-level key and a missing required key — WITHOUT recursing
      # into the verb's deep sub-schemas. The ai verb's deep shapes (an empty
      # prompt.pom [], SWAIG.defaults/web_hook_url/__token) are legitimate
      # renders the bundled schema does not fully accept, so full-deep
      # validating the ai verb would false-reject valid documents. This mirrors
      # the reference: the ai verb rejects stray TOP-LEVEL keys like every other
      # verb, but its inner objects (prompt, SWAIG, params) stay as the handler
      # and runtime define them. params is open by construction — this check
      # never looks inside it.
      #
      # @return [Array(Boolean, Array<String>)] (valid, errors) tuple.
      def validate_verb_top_level_keys(verb_name, verb_config)
        return [true, []] unless @validation_enabled
        return [false, ["Unknown verb: #{verb_name}"]] unless @verbs.key?(verb_name)
        return [true, []] unless verb_config.is_a?(Hash)

        schema = resolved_verb_schema(verb_name)
        return [true, []] if schema.nil?

        errors = top_level_key_errors(verb_name, verb_config, schema)
        [errors.empty?, errors]
      end

      # @api private — the generated method body's trailing lines: fold any extra
      # kwargs into the config, then add the verb.
      #
      # @return [Array<String>] Python source lines
      def method_body_kwargs_lines(verb_name)
        ['        # Add any additional parameters from kwargs',
         '        for key, value in kwargs.items():',
         '            if value is not None:',
         '                config[key] = value', '',
         "        # Add the #{verb_name} verb",
         "        return self.add_verb('#{verb_name}', config)"]
      end

      # @api private — the generated signature's parameter list: `self`, one entry
      # per schema property (required ones without a default), then `**kwargs`.
      #
      # @return [Array<String>]
      def signature_param_parts(verb_name, params, keys)
        required = get_verb_required_properties(verb_name).to_set
        param_parts = keys.map { |name| format_signature_param(name, params[name], required) }
        ['self', *param_parts, '**kwargs']
      end

      # @api private — one generated parameter. A required property is annotated
      # bare; an optional one becomes `Optional[T] = None`.
      #
      # @return [String]
      def format_signature_param(name, defn, required)
        t = python_type_annotation(defn)
        return "#{name}: #{t}" if required.include?(name)

        "#{name}: Optional[#{t}] = None"
      end

      # @api private — the generated method's docstring: a summary line plus one
      # `Args:` entry per property, carrying the schema's own description with
      # newlines flattened.
      #
      # @return [String]
      def signature_docstring(verb_name, params, keys)
        doc = "\"\"\"\n        Add the #{verb_name} verb to the current document\n        \n"
        keys.each do |name|
          desc = ''
          d = params[name]
          desc = d['description'].to_s.tr("\n", ' ').strip if d.is_a?(Hash) && d['description']
          doc << "        Args:\n            #{name}: #{desc}\n"
        end
        doc << "        \n        Returns:\n            True if the verb was added successfully, " \
               "False otherwise\n        \"\"\"\n"
        doc
      end

      # @api private — a verb entry's `definition.properties` block, or nil when the
      # entry does not have that shape.
      #
      # @return [Hash, nil]
      def verb_definition_properties(verb_entry)
        verb_entry['definition']['properties']
      rescue StandardError
        nil
      end

      # @api private — the bundled schema at `lib/signalwire/swml/schema.json`, used
      # when the constructor was given no explicit path.
      #
      # @return [String]
      def default_schema_path
        # Bundled schema lives in lib/signalwire/swml/schema.json
        File.expand_path('../swml/schema.json', __dir__)
      end

      # @api private — whether an environment value reads as true: `1`, `true` or
      # `yes`, case- and whitespace-insensitive.
      #
      # @return [Boolean]
      def env_boolish(value)
        %w[1 true yes].include?(value.to_s.strip.downcase)
      end

      # @api private — build the verb table by walking `$defs.SWMLMethod.anyOf`,
      # which is the schema's registry of every verb. A schema missing that structure
      # leaves the table empty rather than raising.
      def extract_verbs
        defs = @schema['$defs']
        return unless defs.is_a?(Hash)

        swml_method = defs['SWMLMethod']
        return unless swml_method.is_a?(Hash)

        any_of = swml_method['anyOf']
        return unless any_of.is_a?(Array)

        any_of.each { |entry| register_verb_entry(entry, defs) }
      end

      # @api private — resolve one `anyOf` `$ref` to its definition and record it
      # under its ACTUAL verb name — the single key of the definition's `properties`
      # block, which is not always the schema's own name.
      def register_verb_entry(entry, defs)
        schema_name = entry_schema_name(entry)
        return if schema_name.nil?

        defn = defs[schema_name]
        return unless defn.is_a?(Hash)

        props = defn['properties']
        return unless props.is_a?(Hash) && !props.empty?

        actual_verb = props.keys.first
        @verbs[actual_verb] = {
          'name' => actual_verb, 'schema_name' => schema_name, 'definition' => defn
        }
      end

      # The "#/$defs/<name>" ref's <name>, or nil if the entry isn't a valid ref.
      def entry_schema_name(entry)
        return nil unless entry.is_a?(Hash)

        ref = entry['$ref']
        return nil unless ref.is_a?(String)

        prefix = '#/$defs/'
        return nil unless ref.start_with?(prefix)

        ref[prefix.length..]
      end

      # Wire the json_schemer full validator (Draft 2020-12) over the loaded
      # schema, mirroring Python's jsonschema-rs Draft202012Validator. Leaves
      # @full_validator nil (lightweight fallback) if json_schemer is not
      # installed or the schema lacks the full document structure — so a
      # partial/test schema without a 'sections' property never crashes here.
      def init_full_validator
        return unless @schema.is_a?(Hash) && @schema.dig('properties', 'sections')

        require 'json_schemer'
        @full_validator = JSONSchemer.schema(
          apply_sdk_widen(@schema), meta_schema: 'https://json-schema.org/draft/2020-12/schema'
        )
      rescue LoadError, StandardError
        @full_validator = nil
      end

      # Some schema properties mark their `enum`/`const` union as advisory: the
      # listed values are the documented ones, but the platform accepts any
      # value of the same base scalar type. `hangup.reason` is the standing
      # example — the `hangup|busy|decline` union is a hint, and any string is
      # valid on the wire.
      #
      # Validating against the raw union would make this SDK reject documents
      # the platform accepts, so the constraint is dropped on marked properties
      # before the validator is built. Returns a widened copy; the schema itself
      # is untouched, so callers reading it still see the documented values.
      #
      # @return [Hash, Array, Object]
      def apply_sdk_widen(node)
        return node.map { |item| apply_sdk_widen(item) } if node.is_a?(Array)
        return node unless node.is_a?(Hash)
        return widened_scalar(node) if node['x-sdk-widen']

        node.transform_values { |value| apply_sdk_widen(value) }
      end

      # @api private — a widened copy of one marked property: the constraint
      # keywords that pin it to a fixed value set are removed, leaving the base
      # scalar type (recovered from the const-union's members when the property
      # states no `type` of its own).
      #
      # @return [Hash]
      def widened_scalar(node)
        widened = node.except(*WIDEN_STRIPPED_KEYS)
        widened['type'] ||= widen_base_type(node)
        widened.compact
      end

      # @api private — the base scalar type a const-union widens to: whatever
      # `type` its branches agree on, or nil when they do not agree (leaving the
      # property unconstrained rather than guessing).
      #
      # @return [String, nil]
      def widen_base_type(node)
        branches = node['anyOf'] || node['oneOf'] || []
        types = branches.grep(Hash).filter_map { |b| b['type'] }.uniq
        types.length == 1 ? types.first : nil
      end

      # Full JSON Schema validation via json_schemer. Mirrors Python's
      # _validate_verb_full: wrap the verb in a minimal SWML document
      # ({version, sections:{main:[{verb: config}]}}) and validate the whole
      # doc, so the schema's closed-key (`unevaluatedProperties`) and type
      # rules apply to the verb config exactly as they do in the reference.
      def validate_verb_full(verb_name, verb_config)
        return validate_verb_lightweight(verb_name, verb_config) if @full_validator.nil?

        minimal_doc = {
          'version' => '1.0.0',
          'sections' => { 'main' => [{ verb_name => verb_config }] }
        }
        errors = @full_validator.validate(minimal_doc).to_a
        return [true, []] if errors.empty?

        detail = schema_error_detail(verb_name, errors)
        [false, ["Schema validation error for '#{verb_name}': #{detail}"]]
      end

      # Build a concise error string from json_schemer's error records, capped
      # like Python's 500-char truncation.
      def schema_error_detail(_verb_name, errors)
        msg = errors.filter_map { |e| e['error'] || e['type'] }.join('; ')
        msg = "#{msg[0, 500]}..." if msg.length > 500
        msg
      end

      # @api private — the fallback validator used when json_schemer is unavailable:
      # presence of every required property, and nothing deeper. Matches the
      # reference's own lightweight path.
      #
      # @return [Array(Boolean, Array<String>)]
      def validate_verb_lightweight(verb_name, verb_config)
        errors = []
        get_verb_required_properties(verb_name).each do |prop|
          errors << "Missing required property '#{prop}' for verb '#{verb_name}'" unless verb_config.key?(prop)
        end
        [errors.empty?, errors]
      end

      # Resolve a verb's own object schema (following a single top-level $ref,
      # e.g. the ai verb -> #/$defs/AIObject), returning the Hash schema whose
      # `properties` + `required` + closed-key flag define the verb's top level,
      # or nil when it can't be resolved.
      def resolved_verb_schema(verb_name)
        node = get_verb_properties(verb_name)
        return node unless node.is_a?(Hash)

        ref = node['$ref']
        return node unless ref.is_a?(String)

        prefix = '#/$defs/'
        return node unless ref.start_with?(prefix)

        target = @schema.dig('$defs', ref[prefix.length..])
        target.is_a?(Hash) ? target : node
      end

      # Closed-key + required-key errors at the verb's own level. A key not in
      # the schema's declared `properties` is rejected only when the schema is
      # closed (unevaluatedProperties / additionalProperties disallow extras) —
      # matching the reference's closed-verb contract.
      def top_level_key_errors(verb_name, verb_config, schema)
        errors = missing_required_errors(verb_name, verb_config, schema)
        errors.concat(unknown_key_errors(verb_name, verb_config, schema)) if schema_closed?(schema)
        errors
      end

      # @api private — one error per `required` property absent from the config.
      #
      # @return [Array<String>]
      def missing_required_errors(verb_name, verb_config, schema)
        required = schema['required']
        return [] unless required.is_a?(Array)

        required.reject { |req| verb_config.key?(req) }
                .map { |req| "Missing required property '#{req}' for verb '#{verb_name}'" }
      end

      # @api private — one error per config key not declared in the schema's
      # `properties`. Only called for a CLOSED schema; an open one legitimately
      # accepts extras.
      #
      # @return [Array<String>]
      def unknown_key_errors(verb_name, verb_config, schema)
        props = schema['properties']
        allowed = props.is_a?(Hash) ? props.keys : []
        verb_config.keys.reject { |key| allowed.include?(key) }
                        .map { |key| "Unknown property '#{key}' for verb '#{verb_name}'" }
      end

      # Whether a schema disallows unlisted properties (closed), via either the
      # 2020-12 `unevaluatedProperties: {not: {}}` (or false) or the classic
      # `additionalProperties: false`.
      def schema_closed?(schema)
        unevaluated = schema['unevaluatedProperties']
        return true if unevaluated == false
        return true if unevaluated.is_a?(Hash) && unevaluated['not'] == {}

        schema['additionalProperties'] == false
      end

      # @api private — the Python type annotation for a schema property, used by the
      # codegen output. Anything not a known scalar or an array becomes `Any`.
      #
      # @return [String]
      def python_type_annotation(defn)
        return 'Any' unless defn.is_a?(Hash)

        type = defn['type']
        return PYTHON_SCALAR_TYPES[type] if PYTHON_SCALAR_TYPES.key?(type)
        return python_array_annotation(defn) if type == 'array'

        'Any'
      end

      # @api private — `List[T]` for an array property, recursing into `items`; an
      # array with no item schema becomes `List[Any]`.
      #
      # @return [String]
      def python_array_annotation(defn)
        item = defn['items'].is_a?(Hash) ? python_type_annotation(defn['items']) : 'Any'
        "List[#{item}]"
      end
    end
  end
end
