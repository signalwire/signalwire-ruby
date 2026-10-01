# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PromptConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # PromptConfig — generated read-side payload (schema.json $defs schema 'PromptConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PromptConfig
        FIELDS = {
          'digit_timeout' => :object,
          'initial_timeout' => :object,
          'max_digits' => :object,
          'play' => :object,
          'say_gender' => :object,
          'say_language' => :object,
          'say_voice' => :object,
          'speech_end_timeout' => :object,
          'speech_engine' => :object,
          'speech_hints' => :array,
          'speech_language' => :object,
          'speech_timeout' => :object,
          'status_url' => :object,
          'terminators' => :object,
          'url' => :string,
          'volume' => :object
        }.freeze

        attr_reader :digit_timeout, :initial_timeout, :max_digits, :play, :say_gender, :say_language, :say_voice, :speech_end_timeout, :speech_engine, :speech_hints, :speech_language, :speech_timeout, :status_url, :terminators, :url, :volume
      end
    end
  end
end
# rubocop:enable Layout/LineLength
