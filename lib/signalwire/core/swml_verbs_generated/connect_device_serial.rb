# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ConnectDeviceSerial'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ConnectDeviceSerial — generated read-side payload (schema.json $defs schema 'ConnectDeviceSerial').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ConnectDeviceSerial
        FIELDS = {
          'from' => :string,
          'headers' => :array,
          'codecs' => :string,
          'webrtc_media' => :object,
          'session_timeout' => :object,
          'ringback' => :array,
          'result' => :object,
          'timeout' => :object,
          'max_duration' => :object,
          'answer_on_bridge' => :object,
          'confirm' => :object,
          'confirm_timeout' => :object,
          'username' => :string,
          'password' => :string,
          'encryption' => :object,
          'call_state_url' => :string,
          'transfer_after_bridge' => :object,
          'call_state_events' => :array,
          'serial' => :array
        }.freeze

        attr_reader :from, :headers, :codecs, :webrtc_media, :session_timeout, :ringback, :result, :timeout, :max_duration, :answer_on_bridge, :confirm, :confirm_timeout, :username, :password, :encryption, :call_state_url, :transfer_after_bridge, :call_state_events, :serial
      end
    end
  end
end
# rubocop:enable Layout/LineLength
