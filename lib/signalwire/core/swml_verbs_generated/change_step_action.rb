# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ChangeStepAction'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ChangeStepAction — generated read-side payload (schema.json $defs schema 'ChangeStepAction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ChangeStepAction
        FIELDS = {
          'change_step' => :string,
        }.freeze

        attr_reader :change_step
      end
    end
  end
end
