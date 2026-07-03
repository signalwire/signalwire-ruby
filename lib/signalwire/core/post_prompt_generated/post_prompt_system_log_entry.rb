# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptSystemLogEntry'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptSystemLogEntry — generated read-side payload (post-prompt components/schemas 'PostPromptSystemLogEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptSystemLogEntry
        FIELDS = {
          'role' => :string,
          'content' => :string,
          'timestamp' => :integer,
          'action' => :string,
          'lang' => :string,
          'tokens' => :integer,
          'content_type' => :string,
          'metadata' => :object,
          'context' => :string,
          'step' => :string,
          'step_index' => :integer,
        }.freeze

        attr_reader :role
        attr_reader :content
        attr_reader :timestamp
        attr_reader :action
        attr_reader :lang
        attr_reader :tokens
        attr_reader :content_type
        attr_reader :metadata
        attr_reader :context
        attr_reader :step
        attr_reader :step_index
      end
    end
  end
end
