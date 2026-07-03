# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.bind_digit', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingBindDigitParams — generated data type (RELAY method 'calling.bind_digit', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingBindDigitParams
        FIELDS = {
          'bind_method' => :string,
          'call_id' => :string,
          'digits' => :string,
          'max_triggers' => :integer,
          'node_id' => :string,
          'params' => :any,
          'realm' => :string,
          'swml' => :boolean,
        }.freeze
      end
    end
  end
end
