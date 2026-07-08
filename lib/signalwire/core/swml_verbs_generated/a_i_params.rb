# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AIParams'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # AIParams — generated read-side payload (schema.json $defs schema 'AIParams').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class AIParams
        FIELDS = {
          'acknowledge_interruptions' => :object,
          'ai_model' => :object,
          'ai_name' => :string,
          'ai_volume' => :object,
          'app_name' => :string,
          'asr_smart_format' => :object,
          'attention_timeout' => :object,
          'attention_timeout_prompt' => :string,
          'asr_diarize' => :object,
          'asr_speaker_affinity' => :object,
          'background_file' => :string,
          'background_file_loops' => :object,
          'background_file_volume' => :object,
          'enable_barge' => :object,
          'enable_inner_dialog' => :object,
          'enable_pause' => :object,
          'enable_turn_detection' => :object,
          'barge_match_string' => :string,
          'barge_min_words' => :object,
          'barge_functions' => :object,
          'conscience' => :string,
          'convo' => :array,
          'conversation_id' => :string,
          'conversation_sliding_window' => :object,
          'debug_webhook_level' => :object,
          'debug_webhook_url' => :string,
          'debug' => :object,
          'direction' => :object,
          'digit_terminators' => :string,
          'digit_timeout' => :object,
          'end_of_speech_timeout' => :object,
          'enable_thinking' => :object,
          'enable_vision' => :object,
          'energy_level' => :object,
          'first_word_timeout' => :object,
          'function_wait_for_talking' => :object,
          'functions_on_no_response' => :object,
          'hard_stop_prompt' => :string,
          'hard_stop_time' => :object,
          'hold_music' => :string,
          'hold_on_process' => :object,
          'inactivity_timeout' => :object,
          'inner_dialog_model' => :object,
          'inner_dialog_prompt' => :string,
          'inner_dialog_synced' => :object,
          'initial_sleep_ms' => :object,
          'input_poll_freq' => :object,
          'interrupt_on_noise' => :object,
          'interrupt_prompt' => :string,
          # deprecated: languages_enabled
          'languages_enabled' => :object,
          'local_tz' => :string,
          'llm_diarize_aware' => :object,
          'max_emotion' => :object,
          'max_response_tokens' => :object,
          'openai_asr_engine' => :string,
          'outbound_attention_timeout' => :object,
          'persist_global_data' => :object,
          'pom_format' => :object,
          'save_conversation' => :object,
          'speech_event_timeout' => :object,
          'speech_gen_quick_stops' => :object,
          'speech_timeout' => :object,
          'speak_when_spoken_to' => :object,
          'start_paused' => :object,
          'static_greeting' => :string,
          'static_greeting_no_barge' => :object,
          'summary_mode' => :object,
          'swaig_allow_settings' => :object,
          'swaig_allow_swml' => :object,
          'swaig_post_conversation' => :object,
          'swaig_set_global_data' => :object,
          'swaig_post_swml_vars' => :object,
          'thinking_model' => :object,
          'transparent_barge' => :object,
          'transparent_barge_max_time' => :object,
          'transfer_summary' => :object,
          'turn_detection_timeout' => :object,
          'tts_number_format' => :object,
          'video_listening_file' => :string,
          'video_idle_file' => :string,
          'video_talking_file' => :string,
          'vision_model' => :object,
          'vad_config' => :string,
          'wait_for_user' => :object,
          'wake_prefix' => :string,
          'eleven_labs_stability' => :object,
          'eleven_labs_similarity' => :object
        }.freeze

        attr_reader :acknowledge_interruptions, :ai_model, :ai_name, :ai_volume, :app_name, :asr_smart_format, :attention_timeout, :attention_timeout_prompt, :asr_diarize, :asr_speaker_affinity, :background_file, :background_file_loops, :background_file_volume, :enable_barge, :enable_inner_dialog, :enable_pause, :enable_turn_detection, :barge_match_string, :barge_min_words, :barge_functions, :conscience, :convo, :conversation_id, :conversation_sliding_window, :debug_webhook_level, :debug_webhook_url, :debug, :direction, :digit_terminators, :digit_timeout, :end_of_speech_timeout, :enable_thinking, :enable_vision, :energy_level, :first_word_timeout, :function_wait_for_talking, :functions_on_no_response, :hard_stop_prompt, :hard_stop_time, :hold_music, :hold_on_process, :inactivity_timeout, :inner_dialog_model, :inner_dialog_prompt, :inner_dialog_synced, :initial_sleep_ms, :input_poll_freq, :interrupt_on_noise, :interrupt_prompt, :languages_enabled, :local_tz, :llm_diarize_aware, :max_emotion, :max_response_tokens, :openai_asr_engine, :outbound_attention_timeout, :persist_global_data, :pom_format, :save_conversation, :speech_event_timeout, :speech_gen_quick_stops, :speech_timeout, :speak_when_spoken_to, :start_paused, :static_greeting, :static_greeting_no_barge, :summary_mode, :swaig_allow_settings, :swaig_allow_swml, :swaig_post_conversation, :swaig_set_global_data, :swaig_post_swml_vars, :thinking_model, :transparent_barge, :transparent_barge_max_time, :transfer_summary, :turn_detection_timeout, :tts_number_format, :video_listening_file, :video_idle_file, :video_talking_file, :vision_model, :vad_config, :wait_for_user, :wake_prefix, :eleven_labs_stability, :eleven_labs_similarity
      end
    end
  end
end
# rubocop:enable Layout/LineLength
