# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'Webhook'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # Webhook — generated read-side payload (schema.json $defs schema 'Webhook').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class Webhook
        FIELDS = {
          'error_keys' => :object,
          'expressions' => :object,
          'foreach' => :object,
          'form_param' => :string,
          'headers' => :object,
          'input_args_as_params' => :boolean,
          'method' => :string,
          'output' => :object,
          'params' => :object,
          'require_args' => :object,
          'url' => :string
        }.freeze

        attr_reader :error_keys, :expressions, :foreach, :form_param, :headers, :input_args_as_params, :method, :output, :params, :require_args, :url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
