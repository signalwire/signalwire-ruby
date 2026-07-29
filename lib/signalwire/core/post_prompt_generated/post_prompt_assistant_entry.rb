# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptAssistantEntry'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::PostPromptGenerated — namespace for this generated data-class tree.
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
          'text_spoken_total' => :string
        }.freeze

        attr_reader :role, :content, :timestamp, :tool_calls, :latency, :utterance_latency, :audio_latency, :acoustic_latency, :eos_to_push_latency, :dg_decision_latency, :poll, :speech_start_wall_us, :last_word_end_wall_us, :turn_decided_wall_us, :status_pushed_wall_us, :stamps_us, :barged, :barge_elapsed_ms, :text_heard_approx, :text_spoken_total
      end
    end
  end
end
# rubocop:enable Layout/LineLength
