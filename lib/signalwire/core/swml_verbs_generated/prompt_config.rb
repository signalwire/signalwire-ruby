# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'prompt' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # PromptConfig — generated read-side payload (flattened SWMLMethod verb 'prompt' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PromptConfig
        FIELDS = {
          'play' => :object,
          'volume' => :number,
          'say_voice' => :string,
          'say_language' => :string,
          'say_gender' => :string,
          'max_digits' => :object,
          'terminators' => :string,
          'digit_timeout' => :object,
          'initial_timeout' => :object,
          'speech_timeout' => :object,
          'speech_end_timeout' => :object,
          'speech_language' => :string,
          'speech_hints' => :object,
          'speech_engine' => :string,
          'status_url' => :string
        }.freeze

        attr_reader :play, :volume, :say_voice, :say_language, :say_gender, :max_digits, :terminators, :digit_timeout, :initial_timeout, :speech_timeout, :speech_end_timeout, :speech_language, :speech_hints, :speech_engine, :status_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
