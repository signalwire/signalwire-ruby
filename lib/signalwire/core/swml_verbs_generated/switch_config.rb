# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'switch' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SwitchConfig — generated read-side payload (flattened SWMLMethod verb 'switch' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SwitchConfig
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
