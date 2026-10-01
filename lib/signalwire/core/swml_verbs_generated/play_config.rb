# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PlayConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # PlayConfig — generated read-side payload (schema.json $defs schema 'PlayConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PlayConfig
        FIELDS = {
          'auto_answer' => :object,
          'loop' => :object,
          'say_gender' => :object,
          'say_language' => :object,
          'say_voice' => :object,
          'status_url' => :object,
          'url' => :string,
          'urls' => :array,
          'volume' => :object
        }.freeze

        attr_reader :auto_answer, :loop, :say_gender, :say_language, :say_voice, :status_url, :url, :urls, :volume
      end
    end
  end
end
