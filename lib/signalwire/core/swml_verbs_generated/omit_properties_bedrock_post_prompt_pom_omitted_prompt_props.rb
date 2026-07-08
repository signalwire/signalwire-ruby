# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'OmitPropertiesBedrockPostPromptPomOmittedPromptProps'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # OmitPropertiesBedrockPostPromptPomOmittedPromptProps — generated read-side payload (schema.json $defs schema 'OmitPropertiesBedrockPostPromptPomOmittedPromptProps').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class OmitPropertiesBedrockPostPromptPomOmittedPromptProps
        FIELDS = {
          'max_tokens' => :integer,
          'temperature' => :object,
          'top_p' => :object,
          'confidence' => :object,
          'presence_penalty' => :object,
          'frequency_penalty' => :object,
          'pom' => :array
        }.freeze

        attr_reader :max_tokens, :temperature, :top_p, :confidence, :presence_penalty, :frequency_penalty, :pom
      end
    end
  end
end
# rubocop:enable Layout/LineLength
