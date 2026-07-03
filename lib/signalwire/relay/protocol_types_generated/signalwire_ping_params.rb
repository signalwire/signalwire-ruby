# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'signalwire.ping', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # SignalwirePingParams — generated data type (RELAY method 'signalwire.ping', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class SignalwirePingParams
        FIELDS = {
          'payload' => :string,
          'timestamp' => :number,
        }.freeze
      end
    end
  end
end
