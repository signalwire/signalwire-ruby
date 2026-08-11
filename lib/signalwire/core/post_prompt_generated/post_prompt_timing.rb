# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptTiming'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::PostPromptGenerated — namespace for this generated data-class tree.
    module PostPromptGenerated
      # PostPromptTiming — generated read-side payload (post-prompt components/schemas 'PostPromptTiming').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PostPromptTiming
        FIELDS = {
          'hold_ms' => :number,
          'commit_latency_ms' => :number,
          'segments' => :integer,
          'walkbacks' => :integer
        }.freeze

        attr_reader :hold_ms, :commit_latency_ms, :segments, :walkbacks
      end
    end
  end
end
