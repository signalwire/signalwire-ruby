# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'LiveTranslate'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # LiveTranslate — generated read-side payload (schema.json $defs schema 'LiveTranslate').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class LiveTranslate
        FIELDS = {
          'live_translate' => :object,
        }.freeze

        attr_reader :live_translate
      end
    end
  end
end
