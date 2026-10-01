# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiSidecarSWAIGFunctionsItem'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiSidecarSWAIGFunctionsItem — generated read-side payload (schema.json $defs schema 'AiSidecarSWAIGFunctionsItem').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiSidecarSWAIGFunctionsItem
        FIELDS = {
          'description' => :object,
          'function' => :object,
          'parameters' => :object,
          'purpose' => :object,
          'web_hook_auth_pass' => :object,
          'web_hook_auth_password' => :object,
          'web_hook_auth_user' => :object,
          'web_hook_url' => :object
        }.freeze

        attr_reader :description, :function, :parameters, :purpose, :web_hook_auth_pass, :web_hook_auth_password, :web_hook_auth_user, :web_hook_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
