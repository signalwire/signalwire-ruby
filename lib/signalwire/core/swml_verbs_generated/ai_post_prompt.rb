# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiPostPrompt'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiPostPrompt — generated read-side payload (schema.json $defs schema 'AiPostPrompt').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiPostPrompt
        FIELDS = {
          'frequency_penalty' => :any,
          'max_completion_tokens' => :number,
          'max_tokens' => :number,
          'model' => :string,
          'pom' => :array,
          'presence_penalty' => :any,
          'reasoning_effort' => :string,
          'temperature' => :number,
          'text' => :string,
          'top_p' => :number,
          'verbosity' => :string
        }.freeze

        attr_reader :frequency_penalty, :max_completion_tokens, :max_tokens, :model, :pom, :presence_penalty, :reasoning_effort, :temperature, :text, :top_p, :verbosity
      end
    end
  end
end
# rubocop:enable Layout/LineLength
