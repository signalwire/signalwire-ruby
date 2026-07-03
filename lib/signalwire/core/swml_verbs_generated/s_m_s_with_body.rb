# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SMSWithBody'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # SMSWithBody — generated read-side payload (schema.json $defs schema 'SMSWithBody').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class SMSWithBody
        FIELDS = {
          'to_number' => :string,
          'from_number' => :string,
          'region' => :string,
          'tags' => :array,
          'body' => :string,
        }.freeze

        attr_reader :to_number
        attr_reader :from_number
        attr_reader :region
        attr_reader :tags
        attr_reader :body
      end
    end
  end
end
