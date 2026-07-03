# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PickPropertiesHangUpHookSWAIGFunctionPickedSWAIGFunctionProps'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PickPropertiesHangUpHookSWAIGFunctionPickedSWAIGFunctionProps — generated read-side payload (schema.json $defs schema 'PickPropertiesHangUpHookSWAIGFunctionPickedSWAIGFunctionProps').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PickPropertiesHangUpHookSWAIGFunctionPickedSWAIGFunctionProps
        FIELDS = {
          'description' => :string,
          'parameters' => :object,
          'active' => :object,
          'meta_data' => :object,
          'meta_data_token' => :string,
          'data_map' => :object,
          'web_hook_url' => :string,
          'function' => :string,
        }.freeze

        attr_reader :description
        attr_reader :parameters
        attr_reader :active
        attr_reader :meta_data
        attr_reader :meta_data_token
        attr_reader :data_map
        attr_reader :web_hook_url
        attr_reader :function
      end
    end
  end
end
