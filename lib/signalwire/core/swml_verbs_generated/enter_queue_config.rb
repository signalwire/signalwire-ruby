# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'EnterQueueConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # EnterQueueConfig — generated read-side payload (schema.json $defs schema 'EnterQueueConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class EnterQueueConfig
        FIELDS = {
          'execute_after_queue' => :object,
          'queue_name' => :object,
          'status_url' => :object,
          'wait_time' => :object,
          'wait_url' => :object,
          'whisper_url' => :object
        }.freeze

        attr_reader :execute_after_queue, :queue_name, :status_url, :wait_time, :wait_url, :whisper_url
      end
    end
  end
end
