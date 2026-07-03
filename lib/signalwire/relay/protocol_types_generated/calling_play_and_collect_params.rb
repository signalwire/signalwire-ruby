# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.play_and_collect', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingPlayAndCollectParams — generated data type (RELAY method 'calling.play_and_collect', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingPlayAndCollectParams
        FIELDS = {
          'call_id' => :string,
          'collect' => :object,
          'control_id' => :string,
          'node_id' => :string,
          'play' => :array,
          'volume' => :number,
        }.freeze
      end
    end
  end
end
