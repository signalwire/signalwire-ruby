# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'execute' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ExecuteConfig — generated read-side payload (flattened SWMLMethod verb 'execute' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ExecuteConfig
        FIELDS = {
          'dest' => :string,
          'params' => :object,
          'meta' => :object,
          'on_return' => :array,
          'result' => :object,
        }.freeze

        attr_reader :dest
        attr_reader :params
        attr_reader :meta
        attr_reader :on_return
        attr_reader :result
      end
    end
  end
end
