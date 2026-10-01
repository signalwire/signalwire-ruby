# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiLanguagesItemParams'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiLanguagesItemParams — generated read-side payload (schema.json $defs schema 'AiLanguagesItemParams').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiLanguagesItemParams
        FIELDS = {
          'emotion' => :string,
          'pitch' => :object,
          'similarity' => :object,
          'speakingRate' => :object,
          'speed' => :object,
          'stability' => :object,
          'streaming' => :object,
          'temperature' => :object,
          'vol' => :object
        }.freeze

        attr_reader :emotion, :pitch, :similarity, :speakingRate, :speed, :stability, :streaming, :temperature, :vol
      end
    end
  end
end
# rubocop:enable Naming/MethodName
