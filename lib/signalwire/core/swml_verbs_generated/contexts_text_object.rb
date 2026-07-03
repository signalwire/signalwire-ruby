# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ContextsTextObject'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ContextsTextObject — generated read-side payload (schema.json $defs schema 'ContextsTextObject').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ContextsTextObject
        FIELDS = {
          'steps' => :array,
          'isolated' => :boolean,
          'enter_fillers' => :array,
          'exit_fillers' => :array,
          'text' => :string,
        }.freeze

        attr_reader :steps
        attr_reader :isolated
        attr_reader :enter_fillers
        attr_reader :exit_fillers
        attr_reader :text
      end
    end
  end
end
