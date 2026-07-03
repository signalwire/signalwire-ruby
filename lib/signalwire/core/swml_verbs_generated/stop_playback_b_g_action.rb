# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'StopPlaybackBGAction'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # StopPlaybackBGAction — generated read-side payload (schema.json $defs schema 'StopPlaybackBGAction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class StopPlaybackBGAction
        FIELDS = {
          'stop_playback_bg' => :object,
        }.freeze

        attr_reader :stop_playback_bg
      end
    end
  end
end
