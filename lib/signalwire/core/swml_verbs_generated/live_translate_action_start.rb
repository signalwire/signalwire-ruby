# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'LiveTranslateActionStart'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # LiveTranslateActionStart — generated read-side payload (schema.json $defs schema 'LiveTranslateActionStart').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class LiveTranslateActionStart
        FIELDS = {
          'ai_summary' => :object,
          'ai_summary_prompt' => :object,
          'debug_level' => :object,
          'deepgram_key_override' => :object,
          'deepgram_url_override' => :object,
          'direction' => :object,
          'filter_from' => :object,
          'filter_to' => :object,
          'from_lang' => :object,
          'from_voice' => :object,
          'from_voice_params' => :object,
          'live_events' => :object,
          'mode' => :object,
          'speech_engine' => :object,
          'speech_timeout' => :object,
          'to_lang' => :object,
          'to_voice' => :object,
          'to_voice_params' => :object,
          'translation_model' => :object,
          'translation_model_params' => :object,
          'vad_silence_ms' => :object,
          'vad_thresh' => :object,
          'webhook' => :object
        }.freeze

        attr_reader :ai_summary, :ai_summary_prompt, :debug_level, :deepgram_key_override, :deepgram_url_override, :direction, :filter_from, :filter_to, :from_lang, :from_voice, :from_voice_params, :live_events, :mode, :speech_engine, :speech_timeout, :to_lang, :to_voice, :to_voice_params, :translation_model, :translation_model_params, :vad_silence_ms, :vad_thresh, :webhook
      end
    end
  end
end
# rubocop:enable Layout/LineLength
