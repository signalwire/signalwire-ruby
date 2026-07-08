# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.receive', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingReceiveParams — generated data type (RELAY method 'calling.receive', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingReceiveParams
        FIELDS = {
          'context' => :string,
          'contexts' => :array
        }.freeze
      end
    end
  end
end
