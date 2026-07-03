# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SetGlobalDataAction'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SetGlobalDataAction — generated read-side payload (schema.json $defs schema 'SetGlobalDataAction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SetGlobalDataAction
        FIELDS = {
          'set_global_data' => :object,
        }.freeze

        attr_reader :set_global_data
      end
    end
  end
end
