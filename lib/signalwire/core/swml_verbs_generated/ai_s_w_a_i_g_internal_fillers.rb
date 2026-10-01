# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiSWAIGInternalFillers'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiSWAIGInternalFillers — generated read-side payload (schema.json $defs schema 'AiSWAIGInternalFillers').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiSWAIGInternalFillers
        FIELDS = {
          'adjust_response_latency' => :object,
          'change_context' => :object,
          'check_time' => :object,
          'get_ideal_strategy' => :object,
          'get_visual_input' => :object,
          'next_step' => :object,
          'pause_conversation' => :object,
          'wait_for_user' => :object,
          'wait_seconds' => :object
        }.freeze

        attr_reader :adjust_response_latency, :change_context, :check_time, :get_ideal_strategy, :get_visual_input, :next_step, :pause_conversation, :wait_for_user, :wait_seconds
      end
    end
  end
end
# rubocop:enable Layout/LineLength
