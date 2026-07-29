# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'JoinConferenceObject'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
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
          'result' => :object
        }.freeze

        attr_reader :name, :muted, :beep, :start_on_enter, :end_on_exit, :wait_url, :max_participants, :record, :region, :trim, :coach, :status_callback_event, :status_callback, :status_callback_method, :recording_status_callback, :recording_status_callback_method, :recording_status_callback_event, :result
      end
    end
  end
end
# rubocop:enable Layout/LineLength
