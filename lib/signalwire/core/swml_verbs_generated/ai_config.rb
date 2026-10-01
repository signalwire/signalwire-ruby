# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiConfig — generated read-side payload (schema.json $defs schema 'AiConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiConfig
        FIELDS = {
          'SWAIG' => :object,
          'agent' => :object,
          'engine' => :object,
          'global_data' => :object,
          'hints' => :array,
          'languages' => :array,
          'multilingual' => :object,
          'params' => :object,
          'post_prompt' => :object,
          'post_prompt_auth_password' => :object,
          'post_prompt_auth_user' => :object,
          'post_prompt_url' => :object,
          'prompt' => :object,
          'pronounce' => :array,
          'voice' => :object
        }.freeze

        attr_reader :SWAIG, :agent, :engine, :global_data, :hints, :languages, :multilingual, :params, :post_prompt, :post_prompt_auth_password, :post_prompt_auth_user, :post_prompt_url, :prompt, :pronounce, :voice
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
