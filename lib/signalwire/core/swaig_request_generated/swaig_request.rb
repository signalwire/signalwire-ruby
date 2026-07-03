# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# swaig-request `SwaigRequest` schema

module SignalWire
  module Core
    module SwaigRequestGenerated
      # SwaigRequest — generated read-side payload (swaig-request `SwaigRequest` schema).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SwaigRequest
        FIELDS = {
          'ai_session_id' => :string,
          'app_name' => :string,
          'args' => :string,
          'argument' => :object,
          'argument_desc' => :object,
          'call_id' => :string,
          'call_log' => :array,
          'caller_id_name' => :string,
          'caller_id_num' => :string,
          'channel_active' => :boolean,
          'channel_offhook' => :boolean,
          'channel_ready' => :boolean,
          'content_disposition' => :any,
          'content_type' => :any,
          'conversation_id' => :string,
          'description' => :string,
          'error_reason' => :string,
          'fatal_error' => :boolean,
          'function' => :string,
          'global_data' => :object,
          'input' => :string,
          'meta_data' => :object,
          'meta_data_token' => :string,
          'project_id' => :string,
          'raw_call_log' => :array,
          'space_id' => :string,
          'version' => :any,
        }.freeze

        attr_reader :ai_session_id
        attr_reader :app_name
        attr_reader :args
        attr_reader :argument
        attr_reader :argument_desc
        attr_reader :call_id
        attr_reader :call_log
        attr_reader :caller_id_name
        attr_reader :caller_id_num
        attr_reader :channel_active
        attr_reader :channel_offhook
        attr_reader :channel_ready
        attr_reader :content_disposition
        attr_reader :content_type
        attr_reader :conversation_id
        attr_reader :description
        attr_reader :error_reason
        attr_reader :fatal_error
        attr_reader :function
        attr_reader :global_data
        attr_reader :input
        attr_reader :meta_data
        attr_reader :meta_data_token
        attr_reader :project_id
        attr_reader :raw_call_log
        attr_reader :space_id
        attr_reader :version
      end
    end
  end
end
