# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AIPromptPom'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # AIPromptPom — generated read-side payload (schema.json $defs schema 'AIPromptPom').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class AIPromptPom
        FIELDS = {
          'max_tokens' => :integer,
          'temperature' => :object,
          'top_p' => :object,
          'confidence' => :object,
          'presence_penalty' => :object,
          'frequency_penalty' => :object,
          'pom' => :array,
          'contexts' => :object,
        }.freeze

        attr_reader :max_tokens
        attr_reader :temperature
        attr_reader :top_p
        attr_reader :confidence
        attr_reader :presence_penalty
        attr_reader :frequency_penalty
        attr_reader :pom
        attr_reader :contexts
      end
    end
  end
end
