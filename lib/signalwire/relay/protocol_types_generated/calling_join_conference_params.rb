# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.join_conference', params

module SignalWire
  # SignalWire::Relay — namespace for this generated data-class tree.
  module Relay
    # SignalWire::Relay::ProtocolTypesGenerated — namespace for this generated data-class tree.
    module ProtocolTypesGenerated
      # CallingJoinConferenceParams — generated data type (RELAY method 'calling.join_conference', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — the class is a bare
      # namespace for its FIELDS map, describing the wire shape only.
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
          'wait_url' => :string
        }.freeze
      end
    end
  end
end
