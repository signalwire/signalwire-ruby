# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# post-prompt components/schemas 'PostPrompt'

module SignalWire
  module Core
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
          'total_asr_cost_factor' => :number,
        }.freeze

        attr_reader :content_type
        attr_reader :content_disposition
        attr_reader :conversation_type
        attr_reader :action
        attr_reader :project_id
        attr_reader :space_id
        attr_reader :call_id
        attr_reader :app_name
        attr_reader :ai_session_id
        attr_reader :ai_id_tag
        attr_reader :conversation_id
        attr_reader :call_ended_by
        attr_reader :caller_id_name
        attr_reader :caller_id_number
        attr_reader :conversation_summary
        attr_reader :hard_timeout
        attr_reader :call_start_date
        attr_reader :call_answer_date
        attr_reader :call_end_date
        attr_reader :ai_start_date
        attr_reader :ai_end_date
        attr_reader :post_prompt_data
        attr_reader :global_data
        attr_reader :SWMLVars
        attr_reader :SWMLCall
        attr_reader :call_log
        attr_reader :raw_call_log
        attr_reader :call_timeline
        attr_reader :previous_contexts
        attr_reader :times
        attr_reader :swaig_log
        attr_reader :total_minutes
        attr_reader :total_input_tokens
        attr_reader :total_output_tokens
        attr_reader :total_wire_input_tokens
        attr_reader :total_wire_input_tokens_per_minute
        attr_reader :total_wire_output_tokens
        attr_reader :total_wire_output_tokens_per_minute
        attr_reader :total_tts_chars
        attr_reader :total_tts_chars_per_min
        attr_reader :total_asr_minutes
        attr_reader :total_asr_cost_factor
      end
    end
  end
end
