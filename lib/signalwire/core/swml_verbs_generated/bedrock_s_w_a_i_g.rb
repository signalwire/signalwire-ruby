# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'BedrockSWAIG'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # BedrockSWAIG — generated read-side payload (schema.json $defs schema 'BedrockSWAIG').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class BedrockSWAIG
        FIELDS = {
          'functions' => :array,
          'defaults' => :object,
          'native_functions' => :array,
          'includes' => :array,
        }.freeze

        attr_reader :functions
        attr_reader :defaults
        attr_reader :native_functions
        attr_reader :includes
      end
    end
  end
end
