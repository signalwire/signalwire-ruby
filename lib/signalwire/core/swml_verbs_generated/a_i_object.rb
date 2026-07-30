# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AIObject'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AIObject — generated read-side payload (schema.json $defs schema 'AIObject').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AIObject
        FIELDS = {
          'global_data' => :object,
          'hints' => :array,
          'languages' => :array,
          'params' => :object,
          'post_prompt' => :object,
          'post_prompt_url' => :string,
          'pronounce' => :array,
          'prompt' => :object,
          'SWAIG' => :object
        }.freeze

        attr_reader :global_data, :hints, :languages, :params, :post_prompt, :post_prompt_url, :pronounce, :prompt, :SWAIG
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
