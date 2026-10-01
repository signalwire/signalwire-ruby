# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'LiveTranscribeActionStart'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # LiveTranscribeActionStart — generated read-side payload (schema.json $defs schema 'LiveTranscribeActionStart').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class LiveTranscribeActionStart
        FIELDS = {
          'ai_summary' => :object,
          'ai_summary_prompt' => :object,
          'debug_level' => :object,
          'deepgram_key_override' => :object,
          'deepgram_url_override' => :object,
          'direction' => :object,
          'hints' => :object,
          'lang' => :object,
          'live_events' => :object,
          'speech_engine' => :object,
          'speech_timeout' => :object,
          'vad_silence_ms' => :object,
          'vad_thresh' => :object,
          'verbose_utterances' => :object,
          'webhook' => :object
        }.freeze

        attr_reader :ai_summary, :ai_summary_prompt, :debug_level, :deepgram_key_override, :deepgram_url_override, :direction, :hints, :lang, :live_events, :speech_engine, :speech_timeout, :vad_silence_ms, :vad_thresh, :verbose_utterances, :webhook
      end
    end
  end
end
# rubocop:enable Layout/LineLength
