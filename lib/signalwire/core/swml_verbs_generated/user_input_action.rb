# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'UserInputAction'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # UserInputAction — generated read-side payload (schema.json $defs schema 'UserInputAction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class UserInputAction
        FIELDS = {
          'user_input' => :string,
        }.freeze

        attr_reader :user_input
      end
    end
  end
end
