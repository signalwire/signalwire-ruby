# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'pay' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
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
          'voice' => :string
        }.freeze

        attr_reader :payment_connector_url, :charge_amount, :currency, :description, :input, :language, :max_attempts, :min_postal_code_length, :parameters, :payment_method, :postal_code, :prompts, :security_code, :status_url, :timeout, :token_type, :valid_card_types, :voice
      end
    end
  end
end
# rubocop:enable Layout/LineLength
