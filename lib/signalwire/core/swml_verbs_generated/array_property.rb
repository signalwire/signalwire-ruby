# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ArrayProperty'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ArrayProperty — generated read-side payload (schema.json $defs schema 'ArrayProperty').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ArrayProperty
        FIELDS = {
          'description' => :string,
          'nullable' => :object,
          'type' => :string,
          'default' => :array,
          'items' => :object,
        }.freeze

        attr_reader :description
        attr_reader :nullable
        attr_reader :type
        attr_reader :default
        attr_reader :items
      end
    end
  end
end
