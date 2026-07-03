# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'StopDenoise'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # StopDenoise — generated read-side payload (schema.json $defs schema 'StopDenoise').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class StopDenoise
        FIELDS = {
          'stop_denoise' => :object,
        }.freeze

        attr_reader :stop_denoise
      end
    end
  end
end
