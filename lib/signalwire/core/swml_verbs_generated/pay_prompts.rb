# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PayPrompts'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PayPrompts — generated read-side payload (schema.json $defs schema 'PayPrompts').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PayPrompts
        FIELDS = {
          'actions' => :array,
          'for' => :string,
          'attempts' => :string,
          'card_type' => :string,
          'error_type' => :string,
        }.freeze

        attr_reader :actions
        attr_reader :for
        attr_reader :attempts
        attr_reader :card_type
        attr_reader :error_type
      end
    end
  end
end
