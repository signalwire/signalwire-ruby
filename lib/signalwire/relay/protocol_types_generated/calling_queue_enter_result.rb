# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.queue.enter', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingQueueEnterResult — generated data type (RELAY method 'calling.queue.enter', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingQueueEnterResult
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
