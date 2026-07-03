# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ConversationMessage'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ConversationMessage — generated read-side payload (schema.json $defs schema 'ConversationMessage').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ConversationMessage
        FIELDS = {
          'role' => :object,
          'content' => :string,
          'lang' => :string,
        }.freeze

        attr_reader :role
        attr_reader :content
        attr_reader :lang
      end
    end
  end
end
