# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'request' config

module SignalWire
  module Core
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
          'save_variables' => :object,
        }.freeze

        attr_reader :url
        attr_reader :method
        attr_reader :headers
        attr_reader :body
        attr_reader :timeout
        attr_reader :connect_timeout
        attr_reader :save_variables
      end
    end
  end
end
