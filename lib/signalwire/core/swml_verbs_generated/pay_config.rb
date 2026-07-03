# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'pay' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PayConfig — generated read-side payload (flattened SWMLMethod verb 'pay' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PayConfig
        FIELDS = {
          'payment_connector_url' => :string,
          'charge_amount' => :string,
          'currency' => :string,
          'description' => :string,
          'input' => :string,
          'language' => :string,
          'max_attempts' => :object,
          'min_postal_code_length' => :object,
          'parameters' => :array,
          'payment_method' => :string,
          'postal_code' => :object,
          'prompts' => :array,
          'security_code' => :object,
          'status_url' => :string,
          'timeout' => :object,
          'token_type' => :object,
          'valid_card_types' => :string,
          'voice' => :string,
        }.freeze

        attr_reader :payment_connector_url
        attr_reader :charge_amount
        attr_reader :currency
        attr_reader :description
        attr_reader :input
        attr_reader :language
        attr_reader :max_attempts
        attr_reader :min_postal_code_length
        attr_reader :parameters
        attr_reader :payment_method
        attr_reader :postal_code
        attr_reader :prompts
        attr_reader :security_code
        attr_reader :status_url
        attr_reader :timeout
        attr_reader :token_type
        attr_reader :valid_card_types
        attr_reader :voice
      end
    end
  end
end
