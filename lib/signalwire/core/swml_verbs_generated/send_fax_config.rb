# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'send_fax' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SendFaxConfig — generated read-side payload (flattened SWMLMethod verb 'send_fax' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SendFaxConfig
        FIELDS = {
          'document' => :string,
          'header_info' => :string,
          'identity' => :string,
          'status_url' => :string,
        }.freeze

        attr_reader :document
        attr_reader :header_info
        attr_reader :identity
        attr_reader :status_url
      end
    end
  end
end
