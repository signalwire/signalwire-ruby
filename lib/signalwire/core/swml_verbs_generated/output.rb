# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Output'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # Output — generated read-side payload (schema.json $defs schema 'Output').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class Output
        FIELDS = {
          'response' => :string,
          'action' => :array,
        }.freeze

        attr_reader :response
        attr_reader :action
      end
    end
  end
end
