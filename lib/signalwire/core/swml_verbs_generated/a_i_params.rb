# frozen_string_literal: true

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
          'audible_debug' => :object,
          'audible_latency' => :object,
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
          'cache_mode' => :object,
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
          'enable_accounting' => :object,
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
          'verbose_logs' => :object,
          'video_listening_file' => :string,
          'video_idle_file' => :string,
          'video_talking_file' => :string,
          'vision_model' => :object,
          'vad_config' => :string,
          'wait_for_user' => :object,
          'wake_prefix' => :string,
          'eleven_labs_stability' => :object,
          'eleven_labs_similarity' => :object,
        }.freeze

        attr_reader :acknowledge_interruptions
        attr_reader :ai_model
        attr_reader :ai_name
        attr_reader :ai_volume
        attr_reader :app_name
        attr_reader :asr_smart_format
        attr_reader :attention_timeout
        attr_reader :attention_timeout_prompt
        attr_reader :asr_diarize
        attr_reader :asr_speaker_affinity
        attr_reader :audible_debug
        attr_reader :audible_latency
        attr_reader :background_file
        attr_reader :background_file_loops
        attr_reader :background_file_volume
        attr_reader :enable_barge
        attr_reader :enable_inner_dialog
        attr_reader :enable_pause
        attr_reader :enable_turn_detection
        attr_reader :barge_match_string
        attr_reader :barge_min_words
        attr_reader :barge_functions
        attr_reader :cache_mode
        attr_reader :conscience
        attr_reader :convo
        attr_reader :conversation_id
        attr_reader :conversation_sliding_window
        attr_reader :debug_webhook_level
        attr_reader :debug_webhook_url
        attr_reader :debug
        attr_reader :direction
        attr_reader :digit_terminators
        attr_reader :digit_timeout
        attr_reader :end_of_speech_timeout
        attr_reader :enable_accounting
        attr_reader :enable_thinking
        attr_reader :enable_vision
        attr_reader :energy_level
        attr_reader :first_word_timeout
        attr_reader :function_wait_for_talking
        attr_reader :functions_on_no_response
        attr_reader :hard_stop_prompt
        attr_reader :hard_stop_time
        attr_reader :hold_music
        attr_reader :hold_on_process
        attr_reader :inactivity_timeout
        attr_reader :inner_dialog_model
        attr_reader :inner_dialog_prompt
        attr_reader :inner_dialog_synced
        attr_reader :initial_sleep_ms
        attr_reader :input_poll_freq
        attr_reader :interrupt_on_noise
        attr_reader :interrupt_prompt
        attr_reader :languages_enabled
        attr_reader :local_tz
        attr_reader :llm_diarize_aware
        attr_reader :max_emotion
        attr_reader :max_response_tokens
        attr_reader :openai_asr_engine
        attr_reader :outbound_attention_timeout
        attr_reader :persist_global_data
        attr_reader :pom_format
        attr_reader :save_conversation
        attr_reader :speech_event_timeout
        attr_reader :speech_gen_quick_stops
        attr_reader :speech_timeout
        attr_reader :speak_when_spoken_to
        attr_reader :start_paused
        attr_reader :static_greeting
        attr_reader :static_greeting_no_barge
        attr_reader :summary_mode
        attr_reader :swaig_allow_settings
        attr_reader :swaig_allow_swml
        attr_reader :swaig_post_conversation
        attr_reader :swaig_set_global_data
        attr_reader :swaig_post_swml_vars
        attr_reader :thinking_model
        attr_reader :transparent_barge
        attr_reader :transparent_barge_max_time
        attr_reader :transfer_summary
        attr_reader :turn_detection_timeout
        attr_reader :tts_number_format
        attr_reader :verbose_logs
        attr_reader :video_listening_file
        attr_reader :video_idle_file
        attr_reader :video_talking_file
        attr_reader :vision_model
        attr_reader :vad_config
        attr_reader :wait_for_user
        attr_reader :wake_prefix
        attr_reader :eleven_labs_stability
        attr_reader :eleven_labs_similarity
      end
    end
  end
end
