# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'signalwire.execute', params

module SignalWire
  # SignalWire::Relay — namespace for this generated data-class tree.
  module Relay
    # SignalWire::Relay::ProtocolTypesGenerated — namespace for this generated data-class tree.
    module ProtocolTypesGenerated
      # SignalwireExecuteParams — generated data type (RELAY method 'signalwire.execute', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class SignalwireExecuteParams
        FIELDS = {
          'attempted' => :array,
          'method' => :string,
          'params' => :any,
          'protocol' => :string,
          'requester_identity' => :string,
          'requester_nodeid' => :string,
          'responder_identity' => :string,
          'responder_nodeid' => :string
        }.freeze
      end
    end
  end
end
