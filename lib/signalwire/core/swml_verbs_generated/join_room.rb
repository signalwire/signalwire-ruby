# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'JoinRoom'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # JoinRoom — generated read-side payload (schema.json $defs schema 'JoinRoom').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class JoinRoom
        FIELDS = {
          'join_room' => :object,
        }.freeze

        attr_reader :join_room
      end
    end
  end
end
