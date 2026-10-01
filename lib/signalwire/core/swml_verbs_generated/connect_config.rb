# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ConnectConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # ConnectConfig — generated read-side payload (schema.json $defs schema 'ConnectConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class ConnectConfig
        FIELDS = {
          'answer_on_bridge' => :object,
          'authorization_bearer_token' => :object,
          'call_state_events' => :object,
          'call_state_url' => :object,
          'codec' => :object,
          'codecs' => :object,
          'confirm' => :object,
          'confirm_timeout' => :object,
          'custom_parameters' => :object,
          'encryption' => :object,
          'execute_after_queue' => :object,
          'from' => :object,
          'from_name' => :object,
          'headers' => :array,
          'max_duration' => :object,
          'name' => :object,
          'parallel' => :array,
          'password' => :object,
          'realtime' => :object,
          'result' => :object,
          'ringback' => :object,
          'serial' => :array,
          'serial_parallel' => :array,
          'session_timeout' => :object,
          'status_url' => :object,
          'status_url_method' => :object,
          'stop_all_on_reject' => :object,
          'timeout' => :object,
          'to' => :object,
          'username' => :object,
          'webrtc_media' => :object
        }.freeze

        attr_reader :answer_on_bridge, :authorization_bearer_token, :call_state_events, :call_state_url, :codec, :codecs, :confirm, :confirm_timeout, :custom_parameters, :encryption, :execute_after_queue, :from, :from_name, :headers, :max_duration, :name, :parallel, :password, :realtime, :result, :ringback, :serial, :serial_parallel, :session_timeout, :status_url, :status_url_method, :stop_all_on_reject, :timeout, :to, :username, :webrtc_media
      end
    end
  end
end
# rubocop:enable Layout/LineLength
