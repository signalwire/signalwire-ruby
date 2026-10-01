# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.pay', params

module SignalWire
  # SignalWire::Relay — namespace for this generated data-class tree.
  module Relay
    # SignalWire::Relay::ProtocolTypesGenerated — namespace for this generated data-class tree.
    module ProtocolTypesGenerated
      # CallingPayParams — generated data type (RELAY method 'calling.pay', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — the class is a bare
      # namespace for its FIELDS map, describing the wire shape only.
      class CallingPayParams
        FIELDS = {
          'bank_account_type' => :any,
          'call_id' => :string,
          'charge_amount' => :string,
          'control_id' => :string,
          'currency' => :string,
          'description' => :string,
          'input' => :any,
          'language' => :string,
          'max_attempts' => :string,
          'min_postal_code_length' => :string,
          'node_id' => :string,
          'parameters' => :array,
          'payment_connector_url' => :string,
          'payment_method' => :any,
          'postal_code' => :string,
          'prompts' => :array,
          'security_code' => :string,
          'status_url' => :string,
          'timeout' => :string,
          'token_type' => :any,
          'valid_card_types' => :string,
          'voice' => :string
        }.freeze
      end
    end
  end
end
