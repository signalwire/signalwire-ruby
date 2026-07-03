# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PayParameters'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PayParameters — generated read-side payload (schema.json $defs schema 'PayParameters').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PayParameters
        FIELDS = {
          'name' => :string,
          'value' => :string,
        }.freeze

        attr_reader :name
        attr_reader :value
      end
    end
  end
end
