# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AnyOfProperty'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # AnyOfProperty — generated read-side payload (schema.json $defs schema 'AnyOfProperty').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class AnyOfProperty
        FIELDS = {
          'anyOf' => :array,
        }.freeze

        attr_reader :anyOf
      end
    end
  end
end
