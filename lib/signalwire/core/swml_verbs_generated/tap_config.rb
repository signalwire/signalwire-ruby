# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'tap' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # TapConfig — generated read-side payload (flattened SWMLMethod verb 'tap' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class TapConfig
        FIELDS = {
          'uri' => :string,
          'control_id' => :string,
          'direction' => :object,
          'codec' => :object,
          'rtp_ptime' => :object,
          'status_url' => :string
        }.freeze

        attr_reader :uri, :control_id, :direction, :codec, :rtp_ptime, :status_url
      end
    end
  end
end
