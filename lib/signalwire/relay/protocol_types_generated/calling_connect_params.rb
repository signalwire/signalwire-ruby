# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.connect', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingConnectParams — generated data type (RELAY method 'calling.connect', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingConnectParams
        FIELDS = {
          'call_id' => :string,
          'devices' => :array,
          'max_duration' => :integer,
          'max_price_per_minute' => :number,
          'node_id' => :string,
          'ringback' => :array,
          'tag' => :string,
        }.freeze
      end
    end
  end
end
