# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.stream', params

module SignalWire
  # SignalWire::Relay — namespace for this generated data-class tree.
  module Relay
    # SignalWire::Relay::ProtocolTypesGenerated — namespace for this generated data-class tree.
    module ProtocolTypesGenerated
      # CallingStreamParams — generated data type (RELAY method 'calling.stream', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — the class is a bare
      # namespace for its FIELDS map, describing the wire shape only.
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
          'url' => :string
        }.freeze
      end
    end
  end
end
