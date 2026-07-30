# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.bind_digit', params

module SignalWire
  # SignalWire::Relay — namespace for this generated data-class tree.
  module Relay
    # SignalWire::Relay::ProtocolTypesGenerated — namespace for this generated data-class tree.
    module ProtocolTypesGenerated
      # CallingBindDigitParams — generated data type (RELAY method 'calling.bind_digit', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — the class is a bare
      # namespace for its FIELDS map, describing the wire shape only.
      class CallingBindDigitParams
        FIELDS = {
          'bind_method' => :string,
          'call_id' => :string,
          'digits' => :string,
          'max_triggers' => :integer,
          'node_id' => :string,
          'params' => :any,
          'realm' => :string,
          'swml' => :boolean
        }.freeze
      end
    end
  end
end
