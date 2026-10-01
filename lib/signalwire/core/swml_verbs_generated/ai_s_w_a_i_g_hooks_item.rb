# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiSWAIGHooksItem'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiSWAIGHooksItem — generated read-side payload (schema.json $defs schema 'AiSWAIGHooksItem').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiSWAIGHooksItem
        FIELDS = {
          'description' => :string,
          'active' => :object,
          'argument' => :object,
          'data_map' => :object,
          'fillers' => :object,
          'function' => :string,
          'meta_data' => :object,
          'meta_data_token' => :string,
          'parameters' => :object,
          'purpose' => :string,
          'skip_fillers' => :object,
          'wait_file' => :string,
          'wait_file_loops' => :object,
          'wait_for_fillers' => :object,
          'web_hook_auth_pass' => :string,
          'web_hook_auth_password' => :string,
          'web_hook_auth_user' => :string,
          'web_hook_url' => :string
        }.freeze

        attr_reader :description, :active, :argument, :data_map, :fillers, :function, :meta_data, :meta_data_token, :parameters, :purpose, :skip_fillers, :wait_file, :wait_file_loops, :wait_for_fillers, :web_hook_auth_pass, :web_hook_auth_password, :web_hook_auth_user, :web_hook_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
