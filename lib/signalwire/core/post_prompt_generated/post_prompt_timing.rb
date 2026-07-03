# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptTiming'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptTiming — generated read-side payload (post-prompt components/schemas 'PostPromptTiming').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptTiming
        FIELDS = {
          'hold_ms' => :number,
          'commit_latency_ms' => :number,
          'segments' => :integer,
          'walkbacks' => :integer,
        }.freeze

        attr_reader :hold_ms
        attr_reader :commit_latency_ms
        attr_reader :segments
        attr_reader :walkbacks
      end
    end
  end
end
