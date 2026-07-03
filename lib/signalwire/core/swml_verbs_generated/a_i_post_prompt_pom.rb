# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AIPostPromptPom'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # AIPostPromptPom — generated read-side payload (schema.json $defs schema 'AIPostPromptPom').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class AIPostPromptPom
        FIELDS = {
          'max_tokens' => :integer,
          'temperature' => :object,
          'top_p' => :object,
          'confidence' => :object,
          'presence_penalty' => :object,
          'frequency_penalty' => :object,
          'pom' => :array,
        }.freeze

        attr_reader :max_tokens
        attr_reader :temperature
        attr_reader :top_p
        attr_reader :confidence
        attr_reader :presence_penalty
        attr_reader :frequency_penalty
        attr_reader :pom
      end
    end
  end
end
