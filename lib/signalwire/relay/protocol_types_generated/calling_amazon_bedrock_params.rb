# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.amazon_bedrock', params

module SignalWire
  # SignalWire::Relay — namespace for this generated data-class tree.
  module Relay
    # SignalWire::Relay::ProtocolTypesGenerated — namespace for this generated data-class tree.
    module ProtocolTypesGenerated
      # CallingAmazonBedrockParams — generated data type (RELAY method 'calling.amazon_bedrock', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — the class is a bare
      # namespace for its FIELDS map, describing the wire shape only.
      class CallingAmazonBedrockParams
        FIELDS = {
          'SWAIG' => :any,
          'async' => :boolean,
          'call_id' => :string,
          'global_data' => :any,
          'node_id' => :string,
          'params' => :any,
          'post_prompt' => :any,
          'post_prompt_url' => :string,
          'prompt' => :any,
          'swml' => :boolean
        }.freeze
      end
    end
  end
end
