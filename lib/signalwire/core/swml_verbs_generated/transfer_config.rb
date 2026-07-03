# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'transfer' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # TransferConfig — generated read-side payload (flattened SWMLMethod verb 'transfer' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class TransferConfig
        FIELDS = {
          'dest' => :string,
          'params' => :object,
          'meta' => :object,
        }.freeze

        attr_reader :dest
        attr_reader :params
        attr_reader :meta
      end
    end
  end
end
