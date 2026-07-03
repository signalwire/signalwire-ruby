# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.transfer', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingTransferParams — generated data type (RELAY method 'calling.transfer', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingTransferParams
        FIELDS = {
          'call_id' => :string,
          'dest' => :string,
          'node_id' => :string,
        }.freeze
      end
    end
  end
end
