# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

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
          'output' => :object
        }.freeze

        attr_reader :expressions, :error_keys, :url, :foreach, :headers, :method, :input_args_as_params, :params, :require_args, :output
      end
    end
  end
end
# rubocop:enable Layout/LineLength
