# frozen_string_literal: true

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
          'first_audio' => :integer,
        }.freeze

        attr_reader :speech_start
        attr_reader :last_word_end
        attr_reader :suspected_end
        attr_reader :turn_decided
        attr_reader :status_pushed
        attr_reader :request_detect
        attr_reader :first_token
        attr_reader :first_utterance
        attr_reader :first_audio
      end
    end
  end
end
