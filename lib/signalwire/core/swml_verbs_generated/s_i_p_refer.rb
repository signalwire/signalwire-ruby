# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SIPRefer'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SIPRefer — generated read-side payload (schema.json $defs schema 'SIPRefer').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SIPRefer
        FIELDS = {
          'sip_refer' => :object,
        }.freeze

        attr_reader :sip_refer
      end
    end
  end
end
