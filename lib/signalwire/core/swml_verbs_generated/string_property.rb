# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'StringProperty'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # StringProperty — generated read-side payload (schema.json $defs schema 'StringProperty').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class StringProperty
        FIELDS = {
          'description' => :string,
          'nullable' => :object,
          'type' => :string,
          'enum' => :array,
          'default' => :string,
          'pattern' => :string,
          'format' => :object,
        }.freeze

        attr_reader :description
        attr_reader :nullable
        attr_reader :type
        attr_reader :enum
        attr_reader :default
        attr_reader :pattern
        attr_reader :format
      end
    end
  end
end
