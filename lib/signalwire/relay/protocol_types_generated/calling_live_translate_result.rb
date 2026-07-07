# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.live_translate', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingLiveTranslateResult — generated data type (RELAY method 'calling.live_translate', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingLiveTranslateResult
        FIELDS = {
          'call_id' => :string,
          'code' => :string,
          'data' => :any,
          'message' => :string
        }.freeze
      end
    end
  end
end
