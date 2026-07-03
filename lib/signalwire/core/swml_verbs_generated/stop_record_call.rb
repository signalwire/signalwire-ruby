# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'StopRecordCall'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # StopRecordCall — generated read-side payload (schema.json $defs schema 'StopRecordCall').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class StopRecordCall
        FIELDS = {
          'stop_record_call' => :object,
        }.freeze

        attr_reader :stop_record_call
      end
    end
  end
end
