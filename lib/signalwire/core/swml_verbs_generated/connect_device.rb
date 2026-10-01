# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ConnectDevice'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # ConnectDevice — generated read-side payload (schema.json $defs schema 'ConnectDevice').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class ConnectDevice
        FIELDS = {
          'authorization_bearer_token' => :object,
          'call_state_events' => :object,
          'call_state_url' => :object,
          'codec' => :object,
          'codecs' => :object,
          'confirm' => :object,
          'confirm_timeout' => :object,
          'custom_parameters' => :object,
          'encryption' => :object,
          'from' => :object,
          'from_name' => :object,
          'headers' => :array,
          'name' => :object,
          'password' => :object,
          'realtime' => :object,
          'session_timeout' => :object,
          'status_url' => :object,
          'status_url_method' => :object,
          'timeout' => :object,
          'to' => :object,
          'username' => :object,
          'webrtc_media' => :object
        }.freeze

        attr_reader :authorization_bearer_token, :call_state_events, :call_state_url, :codec, :codecs, :confirm, :confirm_timeout, :custom_parameters, :encryption, :from, :from_name, :headers, :name, :password, :realtime, :session_timeout, :status_url, :status_url_method, :timeout, :to, :username, :webrtc_media
      end
    end
  end
end
# rubocop:enable Layout/LineLength
