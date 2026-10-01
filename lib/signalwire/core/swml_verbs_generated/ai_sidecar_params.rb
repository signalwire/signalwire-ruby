# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiSidecarParams'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiSidecarParams — generated read-side payload (schema.json $defs schema 'AiSidecarParams').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiSidecarParams
        FIELDS = {
          'act_on_channel' => :object,
          'ai_summary' => :object,
          'ai_summary_prompt' => :object,
          'debug' => :object,
          'debug_level' => :object,
          'deepgram_key_override' => :object,
          'deepgram_url_override' => :object,
          'final_summary' => :object,
          'idle_timeout_ms' => :object,
          'live_events' => :object,
          'max_history_tokens' => :object,
          'max_iters_per_tick' => :object,
          'min_interval_ms' => :object,
          'speech_engine' => :object,
          'speech_timeout' => :object,
          'summary_model' => :object,
          'transcribe_prompt' => :object,
          'vad_silence_ms' => :object,
          'vad_thresh' => :object,
          'verbose_utterances' => :object
        }.freeze

        attr_reader :act_on_channel, :ai_summary, :ai_summary_prompt, :debug, :debug_level, :deepgram_key_override, :deepgram_url_override, :final_summary, :idle_timeout_ms, :live_events, :max_history_tokens, :max_iters_per_tick, :min_interval_ms, :speech_engine, :speech_timeout, :summary_model, :transcribe_prompt, :vad_silence_ms, :vad_thresh, :verbose_utterances
      end
    end
  end
end
# rubocop:enable Layout/LineLength
