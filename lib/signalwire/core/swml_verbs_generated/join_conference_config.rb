# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'JoinConferenceConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # JoinConferenceConfig — generated read-side payload (schema.json $defs schema 'JoinConferenceConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class JoinConferenceConfig
        FIELDS = {
          'beep' => :object,
          'coach' => :object,
          'emit_call_quality' => :object,
          'end_on_exit' => :object,
          'max_participants' => :object,
          'meta' => :object,
          'min_participants' => :object,
          'muted' => :object,
          'name' => :object,
          'record' => :object,
          'recording_status_callback' => :object,
          'recording_status_callback_event' => :object,
          'recording_status_callback_event_type' => :object,
          'recording_status_callback_method' => :object,
          'region' => :object,
          'start_on_enter' => :object,
          'status_callback' => :object,
          'status_callback_event' => :object,
          'status_callback_event_type' => :object,
          'status_callback_method' => :object,
          'stream' => :object,
          'trim' => :object,
          'video' => :object,
          'video_layout' => :object,
          'video_preview' => :object,
          'video_quality' => :object,
          'wait_url' => :object
        }.freeze

        attr_reader :beep, :coach, :emit_call_quality, :end_on_exit, :max_participants, :meta, :min_participants, :muted, :name, :record, :recording_status_callback, :recording_status_callback_event, :recording_status_callback_event_type, :recording_status_callback_method, :region, :start_on_enter, :status_callback, :status_callback_event, :status_callback_event_type, :status_callback_method, :stream, :trim, :video, :video_layout, :video_preview, :video_quality, :wait_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
