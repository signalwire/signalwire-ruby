# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptToolEntry'

module SignalWire
  module Core
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
          'original_result' => :string,
        }.freeze

        attr_reader :role
        attr_reader :tool_call_id
        attr_reader :content
        attr_reader :timestamp
        attr_reader :function_name
        attr_reader :latency
        attr_reader :utterance_latency
        attr_reader :function_latency
        attr_reader :audio_latency
        attr_reader :execution_latency
        attr_reader :deprecation_warning
        attr_reader :start_timestamp
        attr_reader :end_timestamp
        attr_reader :distilled
        attr_reader :original_result
      end
    end
  end
end
