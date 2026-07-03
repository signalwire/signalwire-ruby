# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Webhook'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # Webhook — generated read-side payload (schema.json $defs schema 'Webhook').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class Webhook
        FIELDS = {
          'expressions' => :array,
          'error_keys' => :object,
          'url' => :string,
          'foreach' => :object,
          'headers' => :object,
          'method' => :object,
          'input_args_as_params' => :object,
          'params' => :object,
          'require_args' => :object,
          'output' => :object,
        }.freeze

        attr_reader :expressions
        attr_reader :error_keys
        attr_reader :url
        attr_reader :foreach
        attr_reader :headers
        attr_reader :method
        attr_reader :input_args_as_params
        attr_reader :params
        attr_reader :require_args
        attr_reader :output
      end
    end
  end
end
