# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

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
          'step_index' => :integer
        }.freeze

        attr_reader :role, :content, :timestamp, :action, :lang, :tokens, :content_type, :metadata, :context, :step, :step_index
      end
    end
  end
end
# rubocop:enable Layout/LineLength
