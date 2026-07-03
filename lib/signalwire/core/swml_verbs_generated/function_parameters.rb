# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'FunctionParameters'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # FunctionParameters — generated read-side payload (schema.json $defs schema 'FunctionParameters').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class FunctionParameters
        FIELDS = {
          'type' => :string,
          'properties' => :object,
          'required' => :array,
        }.freeze

        attr_reader :type
        attr_reader :properties
        attr_reader :required
      end
    end
  end
end
