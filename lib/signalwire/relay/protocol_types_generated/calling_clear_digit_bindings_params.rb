# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.clear_digit_bindings', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingClearDigitBindingsParams — generated data type (RELAY method 'calling.clear_digit_bindings', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingClearDigitBindingsParams
        FIELDS = {
          'call_id' => :string,
          'node_id' => :string,
          'realm' => :string,
          'swml' => :boolean,
        }.freeze
      end
    end
  end
end
