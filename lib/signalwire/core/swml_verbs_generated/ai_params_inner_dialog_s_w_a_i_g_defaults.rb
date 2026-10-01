# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiParamsInnerDialogSWAIGDefaults'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiParamsInnerDialogSWAIGDefaults — generated read-side payload (schema.json $defs schema 'AiParamsInnerDialogSWAIGDefaults').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiParamsInnerDialogSWAIGDefaults
        FIELDS = {
          'web_hook_auth_pass' => :string,
          'web_hook_auth_password' => :string,
          'web_hook_auth_user' => :string,
          'web_hook_url' => :string
        }.freeze

        attr_reader :web_hook_auth_pass, :web_hook_auth_password, :web_hook_auth_user, :web_hook_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
