# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptThinkingEntry'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptThinkingEntry — generated read-side payload (post-prompt components/schemas 'PostPromptThinkingEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptThinkingEntry
        FIELDS = {
          'role' => :string,
          'content' => :string,
          'timestamp' => :integer,
          'lang' => :string,
          'tokens' => :integer,
        }.freeze

        attr_reader :role
        attr_reader :content
        attr_reader :timestamp
        attr_reader :lang
        attr_reader :tokens
      end
    end
  end
end
