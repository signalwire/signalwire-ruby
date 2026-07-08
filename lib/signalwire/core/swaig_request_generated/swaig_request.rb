# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

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
          'version' => :any
        }.freeze

        attr_reader :ai_session_id, :app_name, :args, :argument, :argument_desc, :call_id, :call_log, :caller_id_name, :caller_id_num, :channel_active, :channel_offhook, :channel_ready, :content_disposition, :content_type, :conversation_id, :description, :error_reason, :fatal_error, :function, :global_data, :input, :meta_data, :meta_data_token, :project_id, :raw_call_log, :space_id, :version
      end
    end
  end
end
# rubocop:enable Layout/LineLength
