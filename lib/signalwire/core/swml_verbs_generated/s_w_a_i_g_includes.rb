# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SWAIGIncludes'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SWAIGIncludes — generated read-side payload (schema.json $defs schema 'SWAIGIncludes').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SWAIGIncludes
        FIELDS = {
          'functions' => :array,
          'url' => :string,
          'meta_data' => :object,
        }.freeze

        attr_reader :functions
        attr_reader :url
        attr_reader :meta_data
      end
    end
  end
end
