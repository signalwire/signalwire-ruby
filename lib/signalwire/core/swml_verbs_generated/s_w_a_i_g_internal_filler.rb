# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SWAIGInternalFiller'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # SWAIGInternalFiller — generated read-side payload (schema.json $defs schema 'SWAIGInternalFiller').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
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
          'get_ideal_strategy' => :object
        }.freeze

        attr_reader :hangup, :check_time, :wait_for_user, :wait_seconds, :adjust_response_latency, :next_step, :change_context, :get_visual_input, :get_ideal_strategy
      end
    end
  end
end
# rubocop:enable Layout/LineLength
