# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AmazonBedrockObject'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # AmazonBedrockObject — generated read-side payload (schema.json $defs schema 'AmazonBedrockObject').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class AmazonBedrockObject
        FIELDS = {
          'global_data' => :object,
          'params' => :object,
          'post_prompt' => :object,
          'post_prompt_url' => :string,
          'prompt' => :object,
          'SWAIG' => :object,
        }.freeze

        attr_reader :global_data
        attr_reader :params
        attr_reader :post_prompt
        attr_reader :post_prompt_url
        attr_reader :prompt
        attr_reader :SWAIG
      end
    end
  end
end
