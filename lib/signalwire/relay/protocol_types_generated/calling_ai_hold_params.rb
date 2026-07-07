# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.ai_hold', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingAiHoldParams — generated data type (RELAY method 'calling.ai_hold', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingAiHoldParams
        FIELDS = {
          'async' => :boolean,
          'call_id' => :string,
          'node_id' => :string,
          'prompt' => :string,
          'swml' => :boolean,
          'timeout' => :string
        }.freeze
      end
    end
  end
end
