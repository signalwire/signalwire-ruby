# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ContextsPOMObject'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # ContextsPOMObject — generated read-side payload (schema.json $defs schema 'ContextsPOMObject').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ContextsPOMObject
        FIELDS = {
          'steps' => :array,
          'isolated' => :boolean,
          'enter_fillers' => :array,
          'exit_fillers' => :array,
          'pom' => :array
        }.freeze

        attr_reader :steps, :isolated, :enter_fillers, :exit_fillers, :pom
      end
    end
  end
end
