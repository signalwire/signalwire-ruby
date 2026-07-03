# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Pronounce'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # Pronounce — generated read-side payload (schema.json $defs schema 'Pronounce').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class Pronounce
        FIELDS = {
          'replace' => :string,
          'with' => :string,
          'ignore_case' => :object,
        }.freeze

        attr_reader :replace
        attr_reader :with
        attr_reader :ignore_case
      end
    end
  end
end
