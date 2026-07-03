# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SendSMS'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SendSMS — generated read-side payload (schema.json $defs schema 'SendSMS').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SendSMS
        FIELDS = {
          'send_sms' => :object,
        }.freeze

        attr_reader :send_sms
      end
    end
  end
end
