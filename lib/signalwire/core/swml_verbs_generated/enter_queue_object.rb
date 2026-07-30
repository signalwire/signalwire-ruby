# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'EnterQueueObject'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # EnterQueueObject — generated read-side payload (schema.json $defs schema 'EnterQueueObject').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class EnterQueueObject
        FIELDS = {
          'queue_name' => :string,
          'transfer_after_bridge' => :object,
          'status_url' => :string,
          'wait_url' => :object,
          'wait_time' => :object
        }.freeze

        attr_reader :queue_name, :transfer_after_bridge, :status_url, :wait_url, :wait_time
      end
    end
  end
end
