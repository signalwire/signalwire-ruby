# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.dial', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingDialResult — generated data type (RELAY method 'calling.dial', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingDialResult
        FIELDS = {
          'code' => :string,
          'data' => :any,
          'message' => :string,
          'message_data' => :any,
        }.freeze
      end
    end
  end
end
