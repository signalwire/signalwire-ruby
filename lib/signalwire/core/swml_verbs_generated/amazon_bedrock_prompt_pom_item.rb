# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AmazonBedrockPromptPomItem'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AmazonBedrockPromptPomItem — generated read-side payload (schema.json $defs schema 'AmazonBedrockPromptPomItem').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AmazonBedrockPromptPomItem
        FIELDS = {
          'title' => :string,
          'body' => :string,
          'bullets' => :array,
          'numbered' => :boolean,
          'numberedBullets' => :boolean,
          'subsections' => :array
        }.freeze

        attr_reader :title, :body, :bullets, :numbered, :numberedBullets, :subsections
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
