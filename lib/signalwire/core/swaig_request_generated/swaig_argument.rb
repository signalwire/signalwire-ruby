# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# inline swaig-request `argument` object

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwaigRequestGenerated — namespace for this generated data-class tree.
    module SwaigRequestGenerated
      # SwaigArgument — generated read-side payload (inline swaig-request `argument` object).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class SwaigArgument
        FIELDS = {
          'parsed' => :array,
          'raw' => :string,
          'substituted' => :string
        }.freeze

        attr_reader :parsed, :raw, :substituted
      end
    end
  end
end
