# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptTimesEntry'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptTimesEntry — generated read-side payload (post-prompt components/schemas 'PostPromptTimesEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptTimesEntry
        FIELDS = {
          'response' => :string,
          'response_word_count' => :integer,
          'answer_time' => :number,
          'token_time' => :number,
          'tokens' => :integer,
          'avg_tps' => :number,
          'tps' => :number,
        }.freeze

        attr_reader :response
        attr_reader :response_word_count
        attr_reader :answer_time
        attr_reader :token_time
        attr_reader :tokens
        attr_reader :avg_tps
        attr_reader :tps
      end
    end
  end
end
