# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'prompt' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PromptConfig — generated read-side payload (flattened SWMLMethod verb 'prompt' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
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
          'status_url' => :string,
        }.freeze

        attr_reader :play
        attr_reader :volume
        attr_reader :say_voice
        attr_reader :say_language
        attr_reader :say_gender
        attr_reader :max_digits
        attr_reader :terminators
        attr_reader :digit_timeout
        attr_reader :initial_timeout
        attr_reader :speech_timeout
        attr_reader :speech_end_timeout
        attr_reader :speech_language
        attr_reader :speech_hints
        attr_reader :speech_engine
        attr_reader :status_url
      end
    end
  end
end
