# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptAssistantEntry'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptAssistantEntry — generated read-side payload (post-prompt components/schemas 'PostPromptAssistantEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptAssistantEntry
        FIELDS = {
          'role' => :string,
          'content' => :string,
          'timestamp' => :integer,
          'tool_calls' => :array,
          'latency' => :number,
          'utterance_latency' => :number,
          'audio_latency' => :number,
          'acoustic_latency' => :number,
          'eos_to_push_latency' => :number,
          'dg_decision_latency' => :number,
          'poll' => :number,
          'speech_start_wall_us' => :integer,
          'last_word_end_wall_us' => :integer,
          'turn_decided_wall_us' => :integer,
          'status_pushed_wall_us' => :integer,
          'stamps_us' => :object,
          'barged' => :boolean,
          'barge_elapsed_ms' => :number,
          'text_heard_approx' => :string,
          'text_spoken_total' => :string,
        }.freeze

        attr_reader :role
        attr_reader :content
        attr_reader :timestamp
        attr_reader :tool_calls
        attr_reader :latency
        attr_reader :utterance_latency
        attr_reader :audio_latency
        attr_reader :acoustic_latency
        attr_reader :eos_to_push_latency
        attr_reader :dg_decision_latency
        attr_reader :poll
        attr_reader :speech_start_wall_us
        attr_reader :last_word_end_wall_us
        attr_reader :turn_decided_wall_us
        attr_reader :status_pushed_wall_us
        attr_reader :stamps_us
        attr_reader :barged
        attr_reader :barge_elapsed_ms
        attr_reader :text_heard_approx
        attr_reader :text_spoken_total
      end
    end
  end
end
