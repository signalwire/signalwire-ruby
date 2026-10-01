# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'CallPayPrompts'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # CallPayPrompts — generated read-side payload (schema.json $defs schema 'CallPayPrompts').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class CallPayPrompts
        FIELDS = {
          'actions' => :object,
          'attempt' => :object,
          'card_type' => :object,
          'error_type' => :object,
          'for' => :object,
          'play' => :object,
          'require_matching_inputs' => :object
        }.freeze

        attr_reader :actions, :attempt, :card_type, :error_type, :for, :play, :require_matching_inputs
      end
    end
  end
end
