# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.stream', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingStreamParams — generated data type (RELAY method 'calling.stream', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingStreamParams
        FIELDS = {
          'async' => :boolean,
          'authorization_bearer_token' => :string,
          'call_id' => :string,
          'codec' => :string,
          'control_id' => :string,
          'custom_parameters' => :any,
          'name' => :string,
          'node_id' => :string,
          'status_url' => :string,
          'status_url_method' => :string,
          'swml' => :boolean,
          'track' => :string,
          'url' => :string,
        }.freeze
      end
    end
  end
end
