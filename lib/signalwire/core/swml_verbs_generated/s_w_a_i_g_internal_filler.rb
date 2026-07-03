# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SWAIGInternalFiller'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SWAIGInternalFiller — generated read-side payload (schema.json $defs schema 'SWAIGInternalFiller').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SWAIGInternalFiller
        FIELDS = {
          'hangup' => :object,
          'check_time' => :object,
          'wait_for_user' => :object,
          'wait_seconds' => :object,
          'adjust_response_latency' => :object,
          'next_step' => :object,
          'change_context' => :object,
          'get_visual_input' => :object,
          'get_ideal_strategy' => :object,
        }.freeze

        attr_reader :hangup
        attr_reader :check_time
        attr_reader :wait_for_user
        attr_reader :wait_seconds
        attr_reader :adjust_response_latency
        attr_reader :next_step
        attr_reader :change_context
        attr_reader :get_visual_input
        attr_reader :get_ideal_strategy
      end
    end
  end
end
