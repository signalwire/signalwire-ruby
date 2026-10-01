# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Step'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # Step — generated read-side payload (schema.json $defs schema 'Step').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class Step
        FIELDS = {
          'end' => :object,
          'functions' => :array,
          'gather_info' => :object,
          'history' => :string,
          'name' => :string,
          'pom' => :array,
          'reset' => :object,
          'skip_to_next_step' => :object,
          'skip_user_turn' => :object,
          'step_criteria' => :string,
          'text' => :string,
          'valid_contexts' => :array,
          'valid_steps' => :array
        }.freeze

        attr_reader :end, :functions, :gather_info, :history, :name, :pom, :reset, :skip_to_next_step, :skip_user_turn, :step_criteria, :text, :valid_contexts, :valid_steps
      end
    end
  end
end
# rubocop:enable Layout/LineLength
