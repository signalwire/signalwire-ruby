# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiSWAIG'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiSWAIG — generated read-side payload (schema.json $defs schema 'AiSWAIG').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiSWAIG
        FIELDS = {
          'defaults' => :object,
          'functions' => :array,
          'hooks' => :array,
          'includes' => :array,
          'internal_fillers' => :object,
          'mcp_servers' => :array,
          'native_functions' => :array
        }.freeze

        attr_reader :defaults, :functions, :hooks, :includes, :internal_fillers, :mcp_servers, :native_functions
      end
    end
  end
end
