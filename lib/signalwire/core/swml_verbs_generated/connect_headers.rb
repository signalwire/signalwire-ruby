# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ConnectHeaders'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ConnectHeaders — generated read-side payload (schema.json $defs schema 'ConnectHeaders').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ConnectHeaders
        FIELDS = {
          'name' => :string,
          'value' => :string,
        }.freeze

        attr_reader :name
        attr_reader :value
      end
    end
  end
end
