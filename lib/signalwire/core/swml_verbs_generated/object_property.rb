# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ObjectProperty'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ObjectProperty — generated read-side payload (schema.json $defs schema 'ObjectProperty').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ObjectProperty
        FIELDS = {
          'description' => :string,
          'nullable' => :object,
          'type' => :string,
          'default' => :object,
          'properties' => :object,
          'required' => :array,
        }.freeze

        attr_reader :description
        attr_reader :nullable
        attr_reader :type
        attr_reader :default
        attr_reader :properties
        attr_reader :required
      end
    end
  end
end
