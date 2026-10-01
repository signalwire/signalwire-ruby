# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AmazonBedrockConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AmazonBedrockConfig — generated read-side payload (schema.json $defs schema 'AmazonBedrockConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AmazonBedrockConfig
        FIELDS = {
          'SWAIG' => :object,
          'app_name' => :string,
          'assistant_name' => :string,
          'assistant_prompt' => :string,
          'conversation_id' => :string,
          'global_data' => :object,
          'greeting_prompt' => :object,
          'params' => :object,
          'post_prompt' => :object,
          'post_prompt_url' => :string,
          'prompt' => :object,
          'transcript_webhook_url' => :string
        }.freeze

        attr_reader :SWAIG, :app_name, :assistant_name, :assistant_prompt, :conversation_id, :global_data, :greeting_prompt, :params, :post_prompt, :post_prompt_url, :prompt, :transcript_webhook_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
