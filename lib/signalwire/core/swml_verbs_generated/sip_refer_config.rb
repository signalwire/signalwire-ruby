# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'sip_refer' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SipReferConfig — generated read-side payload (flattened SWMLMethod verb 'sip_refer' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SipReferConfig
        FIELDS = {
          'to_uri' => :string,
          'status_url' => :string,
          'username' => :string,
          'password' => :string,
        }.freeze

        attr_reader :to_uri
        attr_reader :status_url
        attr_reader :username
        attr_reader :password
      end
    end
  end
end
