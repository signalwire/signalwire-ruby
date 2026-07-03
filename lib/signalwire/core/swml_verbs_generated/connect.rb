# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Connect'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # Connect — generated read-side payload (schema.json $defs schema 'Connect').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class Connect
        FIELDS = {
          'connect' => :object,
        }.freeze

        attr_reader :connect
      end
    end
  end
end
