# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AmazonBedrockSWAIGFunctionsItem'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AmazonBedrockSWAIGFunctionsItem — generated read-side payload (schema.json $defs schema 'AmazonBedrockSWAIGFunctionsItem').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AmazonBedrockSWAIGFunctionsItem
        FIELDS = {
          'description' => :string,
          'data_map' => :object,
          'function' => :string,
          'meta_data' => :object,
          'meta_data_token' => :string,
          'parameters' => :object,
          'web_hook_url' => :string
        }.freeze

        attr_reader :description, :data_map, :function, :meta_data, :meta_data_token, :parameters, :web_hook_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
