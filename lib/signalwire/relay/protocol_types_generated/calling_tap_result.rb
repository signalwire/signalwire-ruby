# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.tap', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingTapResult — generated data type (RELAY method 'calling.tap', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingTapResult
        FIELDS = {
          'call_id' => :string,
          'code' => :string,
          'control_id' => :string,
          'data' => :any,
          'message' => :string,
          'source_device' => :object,
        }.freeze
      end
    end
  end
end
