# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AnswerConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AnswerConfig — generated read-side payload (schema.json $defs schema 'AnswerConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AnswerConfig
        FIELDS = {
          'codecs' => :object,
          'max_duration' => :object,
          'password' => :object,
          'username' => :object
        }.freeze

        attr_reader :codecs, :max_duration, :password, :username
      end
    end
  end
end
