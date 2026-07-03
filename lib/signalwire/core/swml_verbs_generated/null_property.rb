# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'NullProperty'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # NullProperty — generated read-side payload (schema.json $defs schema 'NullProperty').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class NullProperty
        FIELDS = {
          'type' => :string,
          'description' => :string,
        }.freeze

        attr_reader :type
        attr_reader :description
      end
    end
  end
end
