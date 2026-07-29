# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'request' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # RequestConfig — generated read-side payload (flattened SWMLMethod verb 'request' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class RequestConfig
        FIELDS = {
          'url' => :string,
          'method' => :object,
          'headers' => :object,
          'body' => :object,
          'timeout' => :object,
          'connect_timeout' => :object,
          'save_variables' => :object
        }.freeze

        attr_reader :url, :method, :headers, :body, :timeout, :connect_timeout, :save_variables
      end
    end
  end
end
