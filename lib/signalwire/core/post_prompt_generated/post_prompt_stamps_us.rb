# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptStampsUs'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptStampsUs — generated read-side payload (post-prompt components/schemas 'PostPromptStampsUs').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptStampsUs
        FIELDS = {
          'speech_start' => :integer,
          'last_word_end' => :integer,
          'suspected_end' => :integer,
          'turn_decided' => :integer,
          'status_pushed' => :integer,
          'request_detect' => :integer,
          'first_token' => :integer,
          'first_utterance' => :integer,
          'first_audio' => :integer
        }.freeze

        attr_reader :speech_start, :last_word_end, :suspected_end, :turn_decided, :status_pushed, :request_detect, :first_token, :first_utterance, :first_audio
      end
    end
  end
end
# rubocop:enable Layout/LineLength
