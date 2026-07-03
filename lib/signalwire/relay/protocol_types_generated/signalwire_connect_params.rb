# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'signalwire.connect', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # SignalwireConnectParams — generated data type (RELAY method 'signalwire.connect', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class SignalwireConnectParams
        FIELDS = {
          'agent' => :string,
          'authentication' => :object,
          'host' => :string,
          'identity' => :string,
          'params' => :object,
          'protocols' => :array,
          'version' => :object,
        }.freeze
      end
    end
  end
end
