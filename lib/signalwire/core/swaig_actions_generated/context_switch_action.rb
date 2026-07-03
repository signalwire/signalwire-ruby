# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# swaig-response action 'context_switch' value object

module SignalWire
  module Core
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
          'full_reset' => :boolean,
        }.freeze
      end
    end
  end
end
