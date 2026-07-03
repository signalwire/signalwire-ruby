# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.detect', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingDetectParams — generated data type (RELAY method 'calling.detect', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingDetectParams
        FIELDS = {
          'call_id' => :string,
          'control_id' => :string,
          'detect' => :object,
          'node_id' => :string,
          'timeout' => :number,
        }.freeze
      end
    end
  end
end
