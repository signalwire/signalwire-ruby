# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'HangUpHookSWAIGFunction'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # HangUpHookSWAIGFunction — generated read-side payload (schema.json $defs schema 'HangUpHookSWAIGFunction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class HangUpHookSWAIGFunction
        FIELDS = {
          'description' => :string,
          'purpose' => :string,
          'parameters' => :object,
          'fillers' => :object,
          'argument' => :object,
          'active' => :object,
          'meta_data' => :object,
          'meta_data_token' => :string,
          'data_map' => :object,
          'skip_fillers' => :object,
          'web_hook_url' => :string,
          'wait_file' => :string,
          'wait_file_loops' => :object,
          'wait_for_fillers' => :object,
          'function' => :string,
        }.freeze

        attr_reader :description
        attr_reader :purpose
        attr_reader :parameters
        attr_reader :fillers
        attr_reader :argument
        attr_reader :active
        attr_reader :meta_data
        attr_reader :meta_data_token
        attr_reader :data_map
        attr_reader :skip_fillers
        attr_reader :web_hook_url
        attr_reader :wait_file
        attr_reader :wait_file_loops
        attr_reader :wait_for_fillers
        attr_reader :function
      end
    end
  end
end
