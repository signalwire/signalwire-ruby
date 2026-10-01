# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiSidecarConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiSidecarConfig — generated read-side payload (schema.json $defs schema 'AiSidecarConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiSidecarConfig
        FIELDS = {
          'SWAIG' => :object,
          'action' => :object,
          'customer_role' => :object,
          'direction' => :object,
          'global_data' => :object,
          'hints' => :object,
          'lang' => :object,
          'model' => :object,
          'params' => :object,
          'permissions' => :object,
          'prompt' => :object,
          'url' => :object
        }.freeze

        attr_reader :SWAIG, :action, :customer_role, :direction, :global_data, :hints, :lang, :model, :params, :permissions, :prompt, :url
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
