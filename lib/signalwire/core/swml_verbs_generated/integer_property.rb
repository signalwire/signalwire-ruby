# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'IntegerProperty'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # IntegerProperty — generated read-side payload (schema.json $defs schema 'IntegerProperty').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class IntegerProperty
        FIELDS = {
          'description' => :string,
          'nullable' => :object,
          'type' => :string,
          'enum' => :array,
          'default' => :object,
        }.freeze

        attr_reader :description
        attr_reader :nullable
        attr_reader :type
        attr_reader :enum
        attr_reader :default
      end
    end
  end
end
