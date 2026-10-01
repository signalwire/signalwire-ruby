# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ExecuteRpcConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # ExecuteRpcConfig — generated read-side payload (schema.json $defs schema 'ExecuteRpcConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class ExecuteRpcConfig
        FIELDS = {
          'call_id' => :object,
          'method' => :object,
          'node_id' => :object,
          'params' => :object
        }.freeze

        attr_reader :call_id, :method, :node_id, :params
      end
    end
  end
end
