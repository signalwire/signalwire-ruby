# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PickPropertiesStartUpHookSWAIGFunctionPickedSWAIGFunctionProps'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # PickPropertiesStartUpHookSWAIGFunctionPickedSWAIGFunctionProps — generated read-side payload (schema.json $defs schema 'PickPropertiesStartUpHookSWAIGFunctionPickedSWAIGFunctionProps').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PickPropertiesStartUpHookSWAIGFunctionPickedSWAIGFunctionProps
        FIELDS = {
          'description' => :string,
          'parameters' => :object,
          'active' => :object,
          'meta_data' => :object,
          'meta_data_token' => :string,
          'data_map' => :object,
          'web_hook_url' => :string,
          'function' => :string
        }.freeze

        attr_reader :description, :parameters, :active, :meta_data, :meta_data_token, :data_map, :web_hook_url, :function
      end
    end
  end
end
# rubocop:enable Layout/LineLength
