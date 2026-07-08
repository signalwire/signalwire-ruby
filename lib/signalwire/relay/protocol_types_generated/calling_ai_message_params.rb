# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.ai_message', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingAiMessageParams — generated data type (RELAY method 'calling.ai_message', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingAiMessageParams
        FIELDS = {
          'async' => :boolean,
          'call_id' => :string,
          'global_data' => :any,
          'message_text' => :string,
          'node_id' => :string,
          'reset' => :any,
          'role' => :string,
          'swml' => :boolean
        }.freeze
      end
    end
  end
end
