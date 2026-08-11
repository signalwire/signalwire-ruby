# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptTimesEntry'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::PostPromptGenerated — namespace for this generated data-class tree.
    module PostPromptGenerated
      # PostPromptTimesEntry — generated read-side payload (post-prompt components/schemas 'PostPromptTimesEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PostPromptTimesEntry
        FIELDS = {
          'response' => :string,
          'response_word_count' => :integer,
          'answer_time' => :number,
          'token_time' => :number,
          'tokens' => :integer,
          'avg_tps' => :number,
          'tps' => :number
        }.freeze

        attr_reader :response, :response_word_count, :answer_time, :token_time, :tokens, :avg_tps, :tps
      end
    end
  end
end
