# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiParamsConvoItem'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiParamsConvoItem — generated read-side payload (schema.json $defs schema 'AiParamsConvoItem').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiParamsConvoItem
        FIELDS = {
          'content' => :string,
          'lang' => :string,
          'role' => :string,
          'tool_call_id' => :string,
          'tool_calls' => :array
        }.freeze

        attr_reader :content, :lang, :role, :tool_call_id, :tool_calls
      end
    end
  end
end
