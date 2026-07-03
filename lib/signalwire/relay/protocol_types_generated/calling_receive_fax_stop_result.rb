# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.receive_fax.stop', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingReceiveFaxStopResult — generated data type (RELAY method 'calling.receive_fax.stop', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingReceiveFaxStopResult
        FIELDS = {
          'call_id' => :string,
          'code' => :string,
          'control_id' => :string,
          'data' => :any,
          'message' => :string,
        }.freeze
      end
    end
  end
end
