# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Expression'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # Expression — generated read-side payload (schema.json $defs schema 'Expression').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class Expression
        FIELDS = {
          'string' => :string,
          'pattern' => :string,
          'output' => :object,
        }.freeze

        attr_reader :string
        attr_reader :pattern
        attr_reader :output
      end
    end
  end
end
