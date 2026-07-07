# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Naming/MethodName

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
          'SWAIG' => :object
        }.freeze

        attr_reader :global_data, :params, :post_prompt, :post_prompt_url, :prompt, :SWAIG
      end
    end
  end
end
# rubocop:enable Naming/MethodName
