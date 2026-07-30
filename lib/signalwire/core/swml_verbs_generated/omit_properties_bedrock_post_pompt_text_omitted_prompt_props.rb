# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'OmitPropertiesBedrockPostPomptTextOmittedPromptProps'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # OmitPropertiesBedrockPostPomptTextOmittedPromptProps — generated read-side payload (schema.json $defs schema 'OmitPropertiesBedrockPostPomptTextOmittedPromptProps').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class OmitPropertiesBedrockPostPomptTextOmittedPromptProps
        FIELDS = {
          'max_tokens' => :integer,
          'temperature' => :object,
          'top_p' => :object,
          'confidence' => :object,
          'presence_penalty' => :object,
          'frequency_penalty' => :object,
          'text' => :string
        }.freeze

        attr_reader :max_tokens, :temperature, :top_p, :confidence, :presence_penalty, :frequency_penalty, :text
      end
    end
  end
end
# rubocop:enable Layout/LineLength
