# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptUserEntry'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::PostPromptGenerated — namespace for this generated data-class tree.
    module PostPromptGenerated
      # PostPromptUserEntry — generated read-side payload (post-prompt components/schemas 'PostPromptUserEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
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
          'timing' => :object
        }.freeze

        attr_reader :role, :content, :timestamp, :confidence, :content_type, :speaker, :start_timestamp, :end_timestamp, :speaking_to_final_event, :speaking_to_turn_detection, :turn_detection_to_final_event, :barge_count, :merged, :merge_count, :entity, :eot, :timing
      end
    end
  end
end
# rubocop:enable Layout/LineLength
