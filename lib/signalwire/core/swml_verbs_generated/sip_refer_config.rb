# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'SipReferConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # SipReferConfig — generated read-side payload (schema.json $defs schema 'SipReferConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class SipReferConfig
        FIELDS = {
          'password' => :object,
          'status_url' => :object,
          'to' => :object,
          'to_uri' => :object,
          'username' => :object
        }.freeze

        attr_reader :password, :status_url, :to, :to_uri, :username
      end
    end
  end
end
