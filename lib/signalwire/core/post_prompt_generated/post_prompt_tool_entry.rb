# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptToolEntry'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::PostPromptGenerated — namespace for this generated data-class tree.
    module PostPromptGenerated
      # PostPromptToolEntry — generated read-side payload (post-prompt components/schemas 'PostPromptToolEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptToolEntry
        FIELDS = {
          'role' => :string,
          'tool_call_id' => :string,
          'content' => :string,
          'timestamp' => :integer,
          'function_name' => :string,
          'latency' => :number,
          'utterance_latency' => :number,
          'function_latency' => :number,
          'audio_latency' => :number,
          'execution_latency' => :number,
          'deprecation_warning' => :string,
          'start_timestamp' => :integer,
          'end_timestamp' => :integer,
          'distilled' => :boolean,
          'original_result' => :string
        }.freeze

        attr_reader :role, :tool_call_id, :content, :timestamp, :function_name, :latency, :utterance_latency, :function_latency, :audio_latency, :execution_latency, :deprecation_warning, :start_timestamp, :end_timestamp, :distilled, :original_result
      end
    end
  end
end
# rubocop:enable Layout/LineLength
