# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'CondReg'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # CondReg — generated read-side payload (schema.json $defs schema 'CondReg').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class CondReg
        FIELDS = {
          'when' => :string,
          'then' => :array,
          'else' => :array,
        }.freeze

        attr_reader :when
        attr_reader :then
        attr_reader :else
      end
    end
  end
end
