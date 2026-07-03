# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.pay', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingPayParams — generated data type (RELAY method 'calling.pay', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
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
          'voice' => :string,
        }.freeze
      end
    end
  end
end
