# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'messaging.send', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # MessagingSendParams — generated data type (RELAY method 'messaging.send', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class MessagingSendParams
        FIELDS = {
          'body' => :string,
          'context' => :string,
          'from_number' => :string,
          'media' => :array,
          'region' => :string,
          'tags' => :array,
          'to_number' => :string,
        }.freeze
      end
    end
  end
end
