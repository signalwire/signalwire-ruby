# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiLanguagesItem'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiLanguagesItem — generated read-side payload (schema.json $defs schema 'AiLanguagesItem').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiLanguagesItem
        FIELDS = {
          'auto_emotion' => :object,
          'auto_speed' => :object,
          'code' => :object,
          'double_turn_fillers' => :array,
          'engine' => :string,
          'fillers' => :array,
          'function_fillers' => :array,
          'listen_language' => :object,
          'model' => :string,
          'name' => :string,
          'params' => :object,
          'pronounce' => :array,
          'speech_fillers' => :array,
          'turn_fillers' => :array,
          'voice' => :string
        }.freeze

        attr_reader :auto_emotion, :auto_speed, :code, :double_turn_fillers, :engine, :fillers, :function_fillers, :listen_language, :model, :name, :params, :pronounce, :speech_fillers, :turn_fillers, :voice
      end
    end
  end
end
# rubocop:enable Layout/LineLength
