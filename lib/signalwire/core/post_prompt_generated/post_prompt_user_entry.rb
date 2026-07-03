# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptUserEntry'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptUserEntry — generated read-side payload (post-prompt components/schemas 'PostPromptUserEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptUserEntry
        FIELDS = {
          'role' => :string,
          'content' => :string,
          'timestamp' => :integer,
          'confidence' => :number,
          'content_type' => :string,
          'speaker' => :string,
          'start_timestamp' => :integer,
          'end_timestamp' => :integer,
          'speaking_to_final_event' => :number,
          'speaking_to_turn_detection' => :number,
          'turn_detection_to_final_event' => :number,
          'barge_count' => :integer,
          'merged' => :boolean,
          'merge_count' => :integer,
          'entity' => :object,
          'eot' => :object,
          'timing' => :object,
        }.freeze

        attr_reader :role
        attr_reader :content
        attr_reader :timestamp
        attr_reader :confidence
        attr_reader :content_type
        attr_reader :speaker
        attr_reader :start_timestamp
        attr_reader :end_timestamp
        attr_reader :speaking_to_final_event
        attr_reader :speaking_to_turn_detection
        attr_reader :turn_detection_to_final_event
        attr_reader :barge_count
        attr_reader :merged
        attr_reader :merge_count
        attr_reader :entity
        attr_reader :eot
        attr_reader :timing
      end
    end
  end
end
