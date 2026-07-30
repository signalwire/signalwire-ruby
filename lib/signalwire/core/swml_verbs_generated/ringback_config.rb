# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'RingbackConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # RingbackConfig — generated read-side payload (schema.json $defs schema 'RingbackConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class RingbackConfig
        FIELDS = {
          'url' => :string,
          'urls' => :array,
          'volume' => :number,
          'auto_answer' => :boolean,
          'say_voice' => :string,
          'say_language' => :string,
          'say_gender' => :string,
          'status_url' => :string,
          'loop' => :integer
        }.freeze

        attr_reader :url, :urls, :volume, :auto_answer, :say_voice, :say_language, :say_gender, :status_url, :loop
      end
    end
  end
end
