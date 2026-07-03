# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.queue.leave', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingQueueLeaveParams — generated data type (RELAY method 'calling.queue.leave', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingQueueLeaveParams
        FIELDS = {
          'call_id' => :string,
          'control_id' => :string,
          'node_id' => :string,
          'queue_id' => :string,
          'queue_name' => :string,
          'status_url' => :string,
        }.freeze
      end
    end
  end
end
