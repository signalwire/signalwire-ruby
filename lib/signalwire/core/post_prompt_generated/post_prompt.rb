# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPrompt'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::PostPromptGenerated — namespace for this generated data-class tree.
    module PostPromptGenerated
      # PostPrompt — generated read-side payload (post-prompt components/schemas 'PostPrompt').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PostPrompt
        FIELDS = {
          'content_type' => :any,
          'content_disposition' => :any,
          'conversation_type' => :any,
          'action' => :any,
          'project_id' => :string,
          'space_id' => :string,
          'call_id' => :string,
          'app_name' => :string,
          'ai_session_id' => :string,
          'ai_id_tag' => :string,
          'conversation_id' => :string,
          'call_ended_by' => :string,
          'caller_id_name' => :string,
          'caller_id_number' => :string,
          'conversation_summary' => :string,
          'hard_timeout' => :boolean,
          'call_start_date' => :integer,
          'call_answer_date' => :integer,
          'call_end_date' => :integer,
          'ai_start_date' => :integer,
          'ai_end_date' => :integer,
          'post_prompt_data' => :object,
          'global_data' => :object,
          'SWMLVars' => :object,
          'SWMLCall' => :object,
          'call_log' => :array,
          'raw_call_log' => :array,
          'call_timeline' => :array,
          'previous_contexts' => :array,
          'times' => :array,
          'swaig_log' => :array,
          'total_minutes' => :number,
          'total_input_tokens' => :number,
          'total_output_tokens' => :number,
          'total_wire_input_tokens' => :number,
          'total_wire_input_tokens_per_minute' => :number,
          'total_wire_output_tokens' => :number,
          'total_wire_output_tokens_per_minute' => :number,
          'total_tts_chars' => :number,
          'total_tts_chars_per_min' => :number,
          'total_asr_minutes' => :number,
          'total_asr_cost_factor' => :number
        }.freeze

        attr_reader :content_type, :content_disposition, :conversation_type, :action, :project_id, :space_id, :call_id, :app_name, :ai_session_id, :ai_id_tag, :conversation_id, :call_ended_by, :caller_id_name, :caller_id_number, :conversation_summary, :hard_timeout, :call_start_date, :call_answer_date, :call_end_date, :ai_start_date, :ai_end_date, :post_prompt_data, :global_data, :SWMLVars, :SWMLCall, :call_log, :raw_call_log, :call_timeline, :previous_contexts, :times, :swaig_log, :total_minutes, :total_input_tokens, :total_output_tokens, :total_wire_input_tokens, :total_wire_input_tokens_per_minute, :total_wire_output_tokens, :total_wire_output_tokens_per_minute, :total_tts_chars, :total_tts_chars_per_min, :total_asr_minutes, :total_asr_cost_factor
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
