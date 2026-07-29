# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'signalwire.connect', params

module SignalWire
  # SignalWire::Relay — namespace for this generated data-class tree.
  module Relay
    # SignalWire::Relay::ProtocolTypesGenerated — namespace for this generated data-class tree.
    module ProtocolTypesGenerated
      # SignalwireConnectParams — generated data type (RELAY method 'signalwire.connect', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class SignalwireConnectParams
        FIELDS = {
          'agent' => :string,
          'authentication' => :object,
          'host' => :string,
          'identity' => :string,
          'params' => :object,
          'protocols' => :array,
          'version' => :object
        }.freeze
      end
    end
  end
end
