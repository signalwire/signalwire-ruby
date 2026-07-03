# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.user_event', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingUserEventParams — generated data type (RELAY method 'calling.user_event', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingUserEventParams
        FIELDS = {
          'async' => :boolean,
          'call_id' => :string,
          'event' => :any,
          'node_id' => :string,
          'swml' => :boolean,
        }.freeze
      end
    end
  end
end
