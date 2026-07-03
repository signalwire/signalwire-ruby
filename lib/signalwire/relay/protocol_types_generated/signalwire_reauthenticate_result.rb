# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'signalwire.reauthenticate', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # SignalwireReauthenticateResult — generated data type (RELAY method 'signalwire.reauthenticate', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class SignalwireReauthenticateResult
        FIELDS = {
          'authentication' => :string,
          'authorization' => :object,
          'ice_servers' => :array,
          'result' => :any,
        }.freeze
      end
    end
  end
end
