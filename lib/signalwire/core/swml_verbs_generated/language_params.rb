# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'LanguageParams'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # LanguageParams — generated read-side payload (schema.json $defs schema 'LanguageParams').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class LanguageParams
        FIELDS = {
          'stability' => :object,
          'similarity' => :object,
        }.freeze

        attr_reader :stability
        attr_reader :similarity
      end
    end
  end
end
