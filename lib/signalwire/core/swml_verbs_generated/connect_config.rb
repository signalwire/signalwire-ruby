# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'connect' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ConnectConfig — generated read-side payload (flattened SWMLMethod verb 'connect' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ConnectConfig
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
          'to' => :string,
          'serial' => :array,
          'parallel' => :array,
          'serial_parallel' => :array,
        }.freeze

        attr_reader :from
        attr_reader :headers
        attr_reader :codecs
        attr_reader :webrtc_media
        attr_reader :session_timeout
        attr_reader :ringback
        attr_reader :result
        attr_reader :timeout
        attr_reader :max_duration
        attr_reader :answer_on_bridge
        attr_reader :confirm
        attr_reader :confirm_timeout
        attr_reader :username
        attr_reader :password
        attr_reader :encryption
        attr_reader :call_state_url
        attr_reader :transfer_after_bridge
        attr_reader :call_state_events
        attr_reader :to
        attr_reader :serial
        attr_reader :parallel
        attr_reader :serial_parallel
      end
    end
  end
end
