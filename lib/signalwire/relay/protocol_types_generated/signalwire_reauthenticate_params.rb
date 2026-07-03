# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'signalwire.reauthenticate', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # SignalwireReauthenticateParams — generated data type (RELAY method 'signalwire.reauthenticate', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class SignalwireReauthenticateParams
        FIELDS = {
          'authentication' => :object,
          'dpop_token' => :string,
        }.freeze
      end
    end
  end
end
