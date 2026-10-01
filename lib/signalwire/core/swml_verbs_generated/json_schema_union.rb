# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'JsonSchemaUnion'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # JsonSchemaUnion — generated read-side payload (schema.json $defs schema 'JsonSchemaUnion').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class JsonSchemaUnion
        FIELDS = {
          'title' => :string,
          'description' => :string,
          'type' => :object,
          'const' => :any,
          'enum' => :array,
          'format' => :string,
          'pattern' => :string,
          'minimum' => :number,
          'maximum' => :number,
          'exclusiveMinimum' => :number,
          'exclusiveMaximum' => :number,
          'minLength' => :integer,
          'maxLength' => :integer,
          'minItems' => :integer,
          'maxItems' => :integer,
          'minProperties' => :integer,
          'maxProperties' => :integer,
          'default' => :any,
          'examples' => :array,
          'deprecated' => :boolean,
          'nullable' => :boolean,
          'properties' => :object,
          'required' => :array,
          'prefixItems' => :array,
          'items' => :object,
          'propertyNames' => :object,
          'additionalProperties' => :object,
          'unevaluatedProperties' => :object,
          'oneOf' => :array,
          'anyOf' => :array,
          'allOf' => :array,
          'not' => :object,
          'contains' => :object,
          'dependentRequired' => :object,
          'dependentSchemas' => :object,
          'else' => :object,
          'example' => :any,
          'if' => :object,
          'maxContains' => :integer,
          'minContains' => :integer,
          'multipleOf' => :number,
          'patternProperties' => :object,
          'propertyOrdering' => :array,
          'readOnly' => :boolean,
          'then' => :object,
          'unevaluatedItems' => :object,
          'uniqueItems' => :boolean,
          'writeOnly' => :boolean
        }.freeze

        attr_reader :title, :description, :type, :const, :enum, :format, :pattern, :minimum, :maximum, :exclusiveMinimum, :exclusiveMaximum, :minLength, :maxLength, :minItems, :maxItems, :minProperties, :maxProperties, :default, :examples, :deprecated, :nullable, :properties, :required, :prefixItems, :items, :propertyNames, :additionalProperties, :unevaluatedProperties, :oneOf, :anyOf, :allOf, :not, :contains, :dependentRequired, :dependentSchemas, :else, :example, :if, :maxContains, :minContains, :multipleOf, :patternProperties, :propertyOrdering, :readOnly, :then, :unevaluatedItems, :uniqueItems, :writeOnly
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
