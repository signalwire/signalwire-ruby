# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ExecuteSwitch'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ExecuteSwitch — generated read-side payload (schema.json $defs schema 'ExecuteSwitch').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ExecuteSwitch
        FIELDS = {
          'variable' => :string,
          'case' => :object,
          'default' => :array,
        }.freeze

        attr_reader :variable
        attr_reader :case
        attr_reader :default
      end
    end
  end
end
