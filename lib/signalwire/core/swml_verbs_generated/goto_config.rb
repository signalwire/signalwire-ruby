# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'goto' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # GotoConfig — generated read-side payload (flattened SWMLMethod verb 'goto' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class GotoConfig
        FIELDS = {
          'label' => :string,
          'when' => :string,
          'max' => :object,
        }.freeze

        attr_reader :label
        attr_reader :when
        attr_reader :max
      end
    end
  end
end
