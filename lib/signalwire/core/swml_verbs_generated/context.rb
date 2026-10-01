# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Context'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # Context — generated read-side payload (schema.json $defs schema 'Context').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class Context
        FIELDS = {
          'consolidate' => :object,
          'enter_fillers' => :object,
          'exit_fillers' => :object,
          'full_reset' => :object,
          'history' => :string,
          'initial_step' => :string,
          'isolated' => :object,
          'pom' => :array,
          'post_prompt' => :object,
          'prompt' => :string,
          'reset' => :object,
          'steps' => :array,
          'system_prompt' => :string,
          'user_prompt' => :string,
          'valid_contexts' => :array,
          'valid_steps' => :array
        }.freeze

        attr_reader :consolidate, :enter_fillers, :exit_fillers, :full_reset, :history, :initial_step, :isolated, :pom, :post_prompt, :prompt, :reset, :steps, :system_prompt, :user_prompt, :valid_contexts, :valid_steps
      end
    end
  end
end
# rubocop:enable Layout/LineLength
