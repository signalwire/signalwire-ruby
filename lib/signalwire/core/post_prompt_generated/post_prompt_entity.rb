# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptEntity'

module SignalWire
  module Core
    module PostPromptGenerated
      # PostPromptEntity — generated read-side payload (post-prompt components/schemas 'PostPromptEntity').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPromptEntity
        FIELDS = {
          'type' => :string,
          'value' => :string,
          'valid' => :boolean
        }.freeze

        attr_reader :type, :value, :valid
      end
    end
  end
end
