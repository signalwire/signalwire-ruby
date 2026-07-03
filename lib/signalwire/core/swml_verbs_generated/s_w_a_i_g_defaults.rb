# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SWAIGDefaults'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SWAIGDefaults — generated read-side payload (schema.json $defs schema 'SWAIGDefaults').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SWAIGDefaults
        FIELDS = {
          'web_hook_url' => :string,
        }.freeze

        attr_reader :web_hook_url
      end
    end
  end
end
