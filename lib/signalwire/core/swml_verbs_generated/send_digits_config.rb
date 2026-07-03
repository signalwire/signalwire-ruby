# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'send_digits' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SendDigitsConfig — generated read-side payload (flattened SWMLMethod verb 'send_digits' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SendDigitsConfig
        FIELDS = {
          'digits' => :string,
        }.freeze

        attr_reader :digits
      end
    end
  end
end
