# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# swaig-response action 'context_switch' value object

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwaigActionsGenerated — namespace for this generated data-class tree.
    module SwaigActionsGenerated
      # ContextSwitchAction — generated read-side payload (swaig-response action 'context_switch' value object).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class ContextSwitchAction
        FIELDS = {
          'consolidate' => :boolean,
          'full_reset' => :boolean,
          'system_pom' => :object,
          'system_prompt' => :string,
          'user_pom' => :object,
          'user_prompt' => :string
        }.freeze

        attr_reader :consolidate, :full_reset, :system_pom, :system_prompt, :user_pom, :user_prompt
      end
    end
  end
end
