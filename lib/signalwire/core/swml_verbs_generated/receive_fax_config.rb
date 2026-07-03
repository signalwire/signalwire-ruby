# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'receive_fax' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ReceiveFaxConfig — generated read-side payload (flattened SWMLMethod verb 'receive_fax' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ReceiveFaxConfig
        FIELDS = {
          'status_url' => :string,
        }.freeze

        attr_reader :status_url
      end
    end
  end
end
