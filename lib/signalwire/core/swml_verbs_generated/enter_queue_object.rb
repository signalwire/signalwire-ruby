# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'EnterQueueObject'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # EnterQueueObject — generated read-side payload (schema.json $defs schema 'EnterQueueObject').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class EnterQueueObject
        FIELDS = {
          'queue_name' => :string,
          'transfer_after_bridge' => :object,
          'status_url' => :string,
          'wait_url' => :object,
          'wait_time' => :object,
        }.freeze

        attr_reader :queue_name
        attr_reader :transfer_after_bridge
        attr_reader :status_url
        attr_reader :wait_url
        attr_reader :wait_time
      end
    end
  end
end
