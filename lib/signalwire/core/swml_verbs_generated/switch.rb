# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Switch'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # Switch — generated read-side payload (schema.json $defs schema 'Switch').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class Switch
        FIELDS = {
          'switch' => :object,
        }.freeze

        attr_reader :switch
      end
    end
  end
end
