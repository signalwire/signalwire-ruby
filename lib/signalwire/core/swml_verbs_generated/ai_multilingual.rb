# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiMultilingual'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiMultilingual — generated read-side payload (schema.json $defs schema 'AiMultilingual').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiMultilingual
        FIELDS = {
          'allowed' => :array,
          'engine' => :string,
          'fillers' => :object,
          'function_fillers' => :object,
          'languages' => :array,
          'min_switch_words' => :number,
          'model' => :string,
          'provider' => :string,
          'start_language' => :string,
          'turn_fillers' => :object
        }.freeze

        attr_reader :allowed, :engine, :fillers, :function_fillers, :languages, :min_switch_words, :model, :provider, :start_language, :turn_fillers
      end
    end
  end
end
# rubocop:enable Layout/LineLength
