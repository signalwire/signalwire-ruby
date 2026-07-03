# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'InjectAction'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # InjectAction — generated read-side payload (schema.json $defs schema 'InjectAction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class InjectAction
        FIELDS = {
          'inject' => :object,
        }.freeze

        attr_reader :inject
      end
    end
  end
end
