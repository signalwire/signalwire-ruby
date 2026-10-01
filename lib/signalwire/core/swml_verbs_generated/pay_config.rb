# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PayConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # PayConfig — generated read-side payload (schema.json $defs schema 'PayConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PayConfig
        FIELDS = {
          'description' => :object,
          'bank_account_type' => :object,
          'charge_amount' => :object,
          'currency' => :object,
          'input' => :object,
          'language' => :object,
          'max_attempts' => :object,
          'min_postal_code_length' => :object,
          'parameters' => :object,
          'payment_connector_url' => :object,
          'payment_method' => :object,
          'postal_code' => :object,
          'prompts' => :object,
          'say_voice' => :object,
          'security_code' => :object,
          'status_url' => :object,
          'timeout' => :object,
          'token_type' => :object,
          'valid_card_types' => :object,
          'voice' => :object
        }.freeze

        attr_reader :description, :bank_account_type, :charge_amount, :currency, :input, :language, :max_attempts, :min_postal_code_length, :parameters, :payment_connector_url, :payment_method, :postal_code, :prompts, :say_voice, :security_code, :status_url, :timeout, :token_type, :valid_card_types, :voice
      end
    end
  end
end
# rubocop:enable Layout/LineLength
