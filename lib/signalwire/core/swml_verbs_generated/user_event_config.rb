# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'user_event' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # UserEventConfig — generated read-side payload (flattened SWMLMethod verb 'user_event' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class UserEventConfig
        FIELDS = {
          'event' => :object,
        }.freeze

        attr_reader :event
      end
    end
  end
end
