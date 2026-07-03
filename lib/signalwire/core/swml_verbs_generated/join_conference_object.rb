# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'JoinConferenceObject'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # JoinConferenceObject — generated read-side payload (schema.json $defs schema 'JoinConferenceObject').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class JoinConferenceObject
        FIELDS = {
          'name' => :string,
          'muted' => :object,
          'beep' => :object,
          'start_on_enter' => :object,
          'end_on_exit' => :object,
          'wait_url' => :object,
          'max_participants' => :object,
          'record' => :object,
          'region' => :string,
          'trim' => :object,
          'coach' => :string,
          'status_callback_event' => :object,
          'status_callback' => :string,
          'status_callback_method' => :object,
          'recording_status_callback' => :string,
          'recording_status_callback_method' => :object,
          'recording_status_callback_event' => :object,
          'result' => :object,
        }.freeze

        attr_reader :name
        attr_reader :muted
        attr_reader :beep
        attr_reader :start_on_enter
        attr_reader :end_on_exit
        attr_reader :wait_url
        attr_reader :max_participants
        attr_reader :record
        attr_reader :region
        attr_reader :trim
        attr_reader :coach
        attr_reader :status_callback_event
        attr_reader :status_callback
        attr_reader :status_callback_method
        attr_reader :recording_status_callback
        attr_reader :recording_status_callback_method
        attr_reader :recording_status_callback_event
        attr_reader :result
      end
    end
  end
end
