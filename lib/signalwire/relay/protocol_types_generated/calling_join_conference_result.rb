# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.join_conference', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingJoinConferenceResult — generated data type (RELAY method 'calling.join_conference', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingJoinConferenceResult
        FIELDS = {
          'call_id' => :string,
          'code' => :string,
          'conference_id' => :string,
          'data' => :any,
          'message' => :string,
        }.freeze
      end
    end
  end
end
