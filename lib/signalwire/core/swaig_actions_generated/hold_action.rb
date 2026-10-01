# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# swaig-response action 'hold' value object

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwaigActionsGenerated — namespace for this generated data-class tree.
    module SwaigActionsGenerated
      # HoldAction — generated read-side payload (swaig-response action 'hold' value object).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class HoldAction
        FIELDS = {
          'step' => :string,
          'timeout' => :number,
          'timeout_step' => :string
        }.freeze

        attr_reader :step, :timeout, :timeout_step
      end
    end
  end
end
