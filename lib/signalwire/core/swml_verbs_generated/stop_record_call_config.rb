# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'stop_record_call' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # StopRecordCallConfig — generated read-side payload (flattened SWMLMethod verb 'stop_record_call' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class StopRecordCallConfig
        FIELDS = {
          'control_id' => :string
        }.freeze

        attr_reader :control_id
      end
    end
  end
end
