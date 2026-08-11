# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SummarizeConversationSWAIGFunction'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # SummarizeConversationSWAIGFunction — generated read-side payload (schema.json $defs schema 'SummarizeConversationSWAIGFunction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class SummarizeConversationSWAIGFunction
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
          'function' => :string
        }.freeze

        attr_reader :description, :purpose, :parameters, :fillers, :argument, :active, :meta_data, :meta_data_token, :data_map, :skip_fillers, :web_hook_url, :wait_file, :wait_file_loops, :wait_for_fillers, :function
      end
    end
  end
end
# rubocop:enable Layout/LineLength
