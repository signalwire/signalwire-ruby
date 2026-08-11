# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'ai_sidecar' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiSidecarConfig — generated read-side payload (flattened SWMLMethod verb 'ai_sidecar' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiSidecarConfig
        FIELDS = {
          'prompt' => :object,
          'lang' => :string,
          'model' => :string,
          'direction' => :array,
          'customer_role' => :string,
          'url' => :string,
          'SWAIG' => :object,
          'permissions' => :object,
          'global_data' => :object,
          'hints' => :array,
          'params' => :object,
          'action' => :any
        }.freeze

        attr_reader :prompt, :lang, :model, :direction, :customer_role, :url, :SWAIG, :permissions, :global_data, :hints, :params, :action
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
