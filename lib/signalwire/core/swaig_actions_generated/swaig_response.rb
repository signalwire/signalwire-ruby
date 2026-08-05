# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# swaig-response components/schemas 'SwaigResponse'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwaigActionsGenerated — namespace for this generated data-class tree.
    module SwaigActionsGenerated
      # SwaigResponse — generated read-side payload (swaig-response components/schemas 'SwaigResponse').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class SwaigResponse
        FIELDS = {
          'response' => :string,
          'action' => :object,
          'post_process' => :boolean
        }.freeze

        attr_reader :response, :action, :post_process
      end
    end
  end
end
