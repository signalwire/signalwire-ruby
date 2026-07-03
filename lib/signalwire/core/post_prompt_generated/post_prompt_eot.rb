# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptEot'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptEot — generated read-side payload (post-prompt components/schemas 'PostPromptEot').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptEot
        FIELDS = {
          'basis' => :string,
          'confidence' => :number,
        }.freeze

        attr_reader :basis
        attr_reader :confidence
      end
    end
  end
end
