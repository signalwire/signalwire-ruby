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
      # ContextSwitchAction — generated data type (swaig-response action 'context_switch' value object).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class ContextSwitchAction
        FIELDS = {
          'system_prompt' => :any,
          'user_prompt' => :any,
          'system_pom' => :any,
          'user_pom' => :any,
          'consolidate' => :boolean,
          'full_reset' => :boolean
        }.freeze
      end
    end
  end
end
