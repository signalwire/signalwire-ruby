# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.amazon_bedrock', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingAmazonBedrockParams — generated data type (RELAY method 'calling.amazon_bedrock', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
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
          'swml' => :boolean,
        }.freeze
      end
    end
  end
end
