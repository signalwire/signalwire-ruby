# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Swaig — the SWAIG function-call surface: results, actions and typed payloads.
  module Swaig
    # ------------------------------------------------------------------
    # ParameterSchema — a typed, block-DSL builder for SWAIG tool
    # parameters.
    #
    # Defining a SWAIG tool's +parameters+ the plain way means
    # hand-writing a JSON-Schema blob as nested Hashes:
    #
    #     define_tool(name: "lookup", description: "...", parameters: {
    #       "service" => { "type" => "string", "description" => "The service" },
    #       "date"    => { "type" => "string", "description" => "YYYY-MM-DD" }
    #     }, required: %w[service date])
    #
    # +ParameterSchema+ is a *typed convenience over the SAME wire output*:
    # the Hash it produces is BYTE-IDENTICAL to the normalised hand-written
    # form (a +{ 'type' => 'object', 'properties' => {...}, 'required' =>
    # [...] }+ object — +required+ omitted when empty). It is NOT a new
    # format; the untyped Hash path stays fully supported. This is purely
    # additive (a PORT_ADDITION).
    #
    # The idiom is a Ruby block DSL — the most natural way to render nested
    # structure readably:
    #
    #     params = SignalWire::Swaig::ParameterSchema.build do
    #       string  :service, 'The service to look up'
    #       string  :date,    'Appointment date, YYYY-MM-DD'
    #       enum    :fmt, RecordFormat::ALL, 'Audio container format'
    #       integer :count,   'How many results', default: 10
    #       array   :tags,    'Search tags', of: :string
    #       object  :filter,  'Structured filter' do
    #         string :status, 'open|closed'
    #       end
    #       required :service, :date
    #     end
    #
    #     # params is the same Hash a hand-written schema would produce:
    #     # { 'type' => 'object', 'properties' => { ... }, 'required' => [...] }
    #
    # The +enum+ kind integrates the Tier-1 frozen closed-set constants
    # ({RecordFormat}, {RecordDirection}, {TapDirection}, {Codec}) — pass
    # any of their +ALL+ arrays (or any literal array) as the closed set and
    # it lands in the schema as +"enum" => [...]+.
    #
    # Supported property kinds: +string+, +number+, +integer+, +boolean+,
    # +enum+ (closed set), +array+ (of a kind), +object+ (nested). Every
    # kind accepts +description+ plus optional +required:+ / +default:+ /
    # +enum:+ / +format:+.
    #
    # The result Hash is plain JSON-Schema — feed it straight to
    # +define_tool(parameters:)+. Because the kind methods return +self+ a
    # fluent style works too:
    #
    #     ParameterSchema.new.string(:q, 'query').require(:q).to_h
    # ------------------------------------------------------------------
    class ParameterSchema
      # JSON-Schema "type" keyword each builder method emits.
      STRING  = 'string'
      NUMBER  = 'number'
      INTEGER = 'integer'
      BOOLEAN = 'boolean'
      ARRAY   = 'array'
      OBJECT  = 'object'

      # Build a schema with the block DSL. The block runs in the builder's
      # instance context, so the bare +string :x, '...'+ verbs resolve to
      # this object's methods.
      #
      #     schema = ParameterSchema.build do
      #       string :name, 'Caller name'
      #       required :name
      #     end #=> Hash
      #
      # @yield DSL body evaluated against a fresh {ParameterSchema}
      # @return [Hash] the JSON-Schema parameters object (byte-identical to
      #   the equivalent hand-written + normalised +parameters+ Hash)
      def self.build(&block)
        builder = new
        builder.instance_eval(&block) if block
        builder.to_h
      end

      # Create an empty builder: no properties and nothing required yet.
      def initialize
        @properties = {}
        @required   = []
      end

      # Add a +string+ property.
      # @param name [String, Symbol] property name (rendered as a String key)
      # @param description [String, nil] LLM-facing description
      # @param required [Boolean] fold this name into the top-level required list
      # @param default [Object, nil] JSON-Schema +default+
      # @param enum [Array, nil] closed set rendered as +enum+
      # @param format [String, nil] JSON-Schema +format+ hint
      # @return [self]
      def string(name, description = nil, required: false, default: nil, enum: nil, format: nil)
        add(name, STRING, description, required: required, default: default, enum: enum, format: format)
      end

      # Add a +number+ (floating-point) property. Same options as {#string}.
      # @return [self]
      def number(name, description = nil, required: false, default: nil, enum: nil, format: nil)
        add(name, NUMBER, description, required: required, default: default, enum: enum, format: format)
      end

      # Add an +integer+ property. Same options as {#string}.
      # @return [self]
      def integer(name, description = nil, required: false, default: nil, enum: nil, format: nil)
        add(name, INTEGER, description, required: required, default: default, enum: enum, format: format)
      end

      # Add a +boolean+ property. Same options as {#string}.
      # @return [self]
      def boolean(name, description = nil, required: false, default: nil)
        add(name, BOOLEAN, description, required: required, default: default)
      end

      # Add a closed-set property (a +string+-typed schema carrying an
      # +enum+ list). Integrates the Tier-1 frozen vocabularies — pass
      # +RecordFormat::ALL+, +TapDirection::ALL+, +Codec::ALL+, etc. (or any
      # literal array) as the +values+ closed set.
      #
      #     enum :fmt, RecordFormat::ALL, 'Audio container format'
      #     #=> properties.fmt == { 'type' => 'string',
      #     #     'description' => '...', 'enum' => ['wav','mp3','mp4'] }
      #
      # @param name [String, Symbol] property name
      # @param values [Array] the closed set (e.g. a constant module's +ALL+)
      # @param description [String, nil] LLM-facing description
      # @param required [Boolean] fold into the top-level required list
      # @param default [Object, nil] JSON-Schema +default+
      # @param type [String] the JSON-Schema scalar type the members are
      #   (defaults to +string+; pass +'integer'+ etc. for numeric enums)
      # @return [self]
      def enum(name, values, description = nil, required: false, default: nil, type: STRING)
        # Copy the closed set so a frozen constant ALL array is never aliased
        # into (and thus mutable through) the produced schema.
        add(name, type, description, required: required, default: default, enum: Array(values).dup)
      end

      # Add an +array+ property. The element kind is given by +of:+ (a JSON
      # type string like +'string'+ / +:integer+), producing an +items+
      # subschema. When +of:+ names +object+ (or +:object+) a block may
      # define the element object's properties.
      #
      #     array :tags, 'Search tags', of: :string
      #     #=> properties.tags == { 'type' => 'array',
      #     #     'description' => '...', 'items' => { 'type' => 'string' } }
      #
      #     array :people, 'Attendees', of: :object do
      #       string :name, 'Full name'
      #     end
      #
      # @param name [String, Symbol] property name
      # @param description [String, nil] LLM-facing description
      # @param of [String, Symbol, nil] element JSON type; nil → no +items+
      # @param required [Boolean] fold into the top-level required list
      # @param default [Object, nil] JSON-Schema +default+
      # @param enum [Array, nil] closed set for the array's +items+
      # @yield nested element-object property DSL (only when +of: :object+)
      # @return [self]
      def array(name, description = nil, of: nil, required: false, default: nil, enum: nil, &)
        extra = {}
        extra['items'] = build_array_items(of.to_s, enum, &) if of
        add(name, ARRAY, description, required: required, default: default, extra: extra)
      end

      # Add a nested +object+ property whose sub-properties are defined in
      # the block (a recursively-evaluated {ParameterSchema}).
      #
      #     object :address, 'Mailing address' do
      #       string :street, 'Street line'
      #       string :zip,    'Postal code'
      #       required :street
      #     end
      #
      # The nested object's own +required+ list (from a nested +required+
      # call) is carried inside the sub-schema, exactly as a hand-written
      # nested object would render.
      #
      # @param name [String, Symbol] property name
      # @param description [String, nil] LLM-facing description
      # @param required [Boolean] fold THIS property into the PARENT's
      #   required list
      # @yield nested property DSL
      # @return [self]
      def object(name, description = nil, required: false, &block)
        extra = {}
        if block
          nested_schema = nested_schema_from(&block)
          extra['properties'] = nested_schema['properties']
          extra['required']   = nested_schema['required'] if nested_schema.key?('required')
        else
          extra['properties'] = {}
        end
        add(name, OBJECT, description, required: required, extra: extra)
      end

      # Mark one or more already-declared (or to-be-declared) properties as
      # required. Names are de-duplicated, preserving first-seen order — the
      # same shape +define_tool(required:)+ produces.
      #
      #     required :service, :date
      #
      # @param names [Array<String, Symbol>]
      # @return [self]
      def required(*names)
        names.flatten.each do |n|
          key = n.to_s
          @required << key unless @required.include?(key)
        end
        self
      end

      # Singular alias of {#required} for fluent single-property chains
      # (+.string(:q,'..').require(:q)+). Avoids reading as a plural when
      # only one name is passed.
      # @return [self]
      def require(*names)
        required(*names)
      end

      # Render the JSON-Schema parameters object.
      #
      # Shape (byte-identical to a hand-written + normalised schema):
      #   - always +'type' => 'object'+
      #   - +'properties' => {...}+ (insertion-ordered)
      #   - +'required' => [...]+ ONLY when at least one name is required
      #     (omitted entirely otherwise — matching +define_tool+, which only
      #     writes +required+ when the supplied Array is non-empty)
      #
      # @return [Hash]
      def to_h
        schema = {
          'type' => OBJECT,
          'properties' => @properties
        }
        schema['required'] = @required unless @required.empty?
        schema
      end
      alias to_hash to_h

      # @return [String] JSON serialization of {#to_h}
      def to_json(*)
        to_h.to_json(*)
      end

      private

      # Build the +items+ subschema for {#array}. Emits +type+, then +enum+
      # (when given), then nested +properties+/+required+ for object items.
      def build_array_items(of_type, enum, &block)
        items = { 'type' => of_type }
        items['enum'] = Array(enum).dup if enum
        if of_type == OBJECT && block
          nested_schema = nested_schema_from(&block)
          items['properties'] = nested_schema['properties']
          items['required']   = nested_schema['required'] if nested_schema.key?('required')
        end
        items
      end

      # Evaluate a nested-property block in a fresh schema and return its hash.
      def nested_schema_from(&)
        nested = self.class.new
        nested.instance_eval(&)
        nested.to_h
      end

      # Build one property subschema in JSON-Schema key order
      # (+type+, +description+, then +enum+ / +format+ / +default+ / +items+
      # / +properties+) and register the name. When +required:+ is truthy the
      # name folds into the top-level required list.
      def add(name, type, description, required: false, default: nil, enum: nil, format: nil, extra: {})
        key = name.to_s
        @properties[key] = build_prop(type, description, default: default, enum: enum, format: format, extra: extra)
        required(key) if required
        self
      end

      # Assemble a property subschema in canonical JSON-Schema key order:
      # +type+, +description+, +enum+, +format+, then +extra+ (+items+ /
      # +properties+), and +default+ last. +default+ is emitted whenever the
      # caller passed one (including +false+), so the nil-guard ordering above
      # can't shadow an explicit nil-able default.
      def build_prop(type, description, default:, enum:, format:, extra:)
        prop = { 'type' => type }
        prop['description'] = description unless description.nil?
        prop['enum']   = enum   unless enum.nil?
        prop['format'] = format unless format.nil?
        prop.merge!(extra) if extra && !extra.empty?
        prop['default'] = default unless default.nil?
        prop
      end
    end
  end
end
