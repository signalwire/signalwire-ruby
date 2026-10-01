# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPromptSystemLogEntry'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::PostPromptGenerated — namespace for this generated data-class tree.
    module PostPromptGenerated
      # PostPromptSystemLogEntry — generated read-side payload (post-prompt components/schemas 'PostPromptSystemLogEntry').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PostPromptSystemLogEntry
        FIELDS = {
          'role' => :string,
          'content' => :string,
          'timestamp' => :integer,
          'action' => :string,
          'lang' => :string,
          'tokens' => :integer,
          'content_type' => :string,
          'metadata' => :object
        }.freeze

        attr_reader :role, :content, :timestamp, :action, :lang, :tokens, :content_type, :metadata
      end
    end
  end
end
# rubocop:enable Layout/LineLength
