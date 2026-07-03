# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.dial', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingDialParams — generated data type (RELAY method 'calling.dial', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingDialParams
        FIELDS = {
          'devices' => :array,
          'max_price_per_minute' => :number,
          'node_id' => :string,
          'region' => :string,
          'tag' => :string,
        }.freeze
      end
    end
  end
end
