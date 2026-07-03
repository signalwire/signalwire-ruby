# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PayPromptSayAction'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PayPromptSayAction — generated read-side payload (schema.json $defs schema 'PayPromptSayAction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PayPromptSayAction
        FIELDS = {
          'type' => :string,
          'phrase' => :string,
        }.freeze

        attr_reader :type
        attr_reader :phrase
      end
    end
  end
end
