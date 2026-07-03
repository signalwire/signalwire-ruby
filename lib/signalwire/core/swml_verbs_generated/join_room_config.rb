# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'join_room' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # JoinRoomConfig — generated read-side payload (flattened SWMLMethod verb 'join_room' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class JoinRoomConfig
        FIELDS = {
          'name' => :string,
        }.freeze

        attr_reader :name
      end
    end
  end
end
