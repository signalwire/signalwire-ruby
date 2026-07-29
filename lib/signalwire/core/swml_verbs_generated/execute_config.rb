# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'execute' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # ExecuteConfig — generated read-side payload (flattened SWMLMethod verb 'execute' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ExecuteConfig
        FIELDS = {
          'dest' => :string,
          'params' => :object,
          'meta' => :object,
          'on_return' => :array,
          'result' => :object
        }.freeze

        attr_reader :dest, :params, :meta, :on_return, :result
      end
    end
  end
end
