# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PlayWithURLS'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PlayWithURLS — generated read-side payload (schema.json $defs schema 'PlayWithURLS').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PlayWithURLS
        FIELDS = {
          'auto_answer' => :object,
          'volume' => :object,
          'say_voice' => :string,
          'say_language' => :string,
          'say_gender' => :string,
          'status_url' => :string,
          'urls' => :object
        }.freeze

        attr_reader :auto_answer, :volume, :say_voice, :say_language, :say_gender, :status_url, :urls
      end
    end
  end
end
