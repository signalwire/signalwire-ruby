# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'tap' config

module SignalWire
  module Core
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
          'status_url' => :string,
        }.freeze

        attr_reader :uri
        attr_reader :control_id
        attr_reader :direction
        attr_reader :codec
        attr_reader :rtp_ptime
        attr_reader :status_url
      end
    end
  end
end
