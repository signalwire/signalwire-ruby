# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'TapConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # TapConfig — generated read-side payload (schema.json $defs schema 'TapConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class TapConfig
        FIELDS = {
          'codec' => :object,
          'control_id' => :object,
          'direction' => :object,
          'rtp_ptime' => :object,
          'status_url' => :object,
          'uri' => :object
        }.freeze

        attr_reader :codec, :control_id, :direction, :rtp_ptime, :status_url, :uri
      end
    end
  end
end
