# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.join_conference', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingJoinConferenceParams — generated data type (RELAY method 'calling.join_conference', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingJoinConferenceParams
        FIELDS = {
          'acl' => :string,
          'beep' => :string,
          'call_id' => :string,
          'coach' => :string,
          'end_on_exit' => :boolean,
          'max_participants' => :integer,
          'muted' => :boolean,
          'name' => :string,
          'node_id' => :string,
          'record' => :string,
          'recording_status_callback' => :string,
          'recording_status_callback_event' => :string,
          'recording_status_callback_event_type' => :string,
          'recording_status_callback_method' => :string,
          'region' => :string,
          'start_on_enter' => :boolean,
          'status_callback' => :string,
          'status_callback_event' => :string,
          'status_callback_event_type' => :string,
          'status_callback_method' => :string,
          'stream' => :any,
          'swml' => :boolean,
          'trim' => :string,
          'wait_url' => :string,
        }.freeze
      end
    end
  end
end
