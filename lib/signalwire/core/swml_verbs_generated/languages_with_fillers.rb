# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'LanguagesWithFillers'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # LanguagesWithFillers — generated read-side payload (schema.json $defs schema 'LanguagesWithFillers').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class LanguagesWithFillers
        FIELDS = {
          'name' => :string,
          'code' => :string,
          'voice' => :string,
          'model' => :string,
          'emotion' => :string,
          'speed' => :string,
          'engine' => :string,
          'params' => :object,
          'function_fillers' => :array,
          'speech_fillers' => :array
        }.freeze

        attr_reader :name, :code, :voice, :model, :emotion, :speed, :engine, :params, :function_fillers, :speech_fillers
      end
    end
  end
end
