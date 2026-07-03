# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'LanguagesWithSoloFillers'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # LanguagesWithSoloFillers — generated read-side payload (schema.json $defs schema 'LanguagesWithSoloFillers').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class LanguagesWithSoloFillers
        FIELDS = {
          'name' => :string,
          'code' => :string,
          'voice' => :string,
          'model' => :string,
          'emotion' => :string,
          'speed' => :string,
          'engine' => :string,
          'params' => :object,
          'fillers' => :array,
        }.freeze

        attr_reader :name
        attr_reader :code
        attr_reader :voice
        attr_reader :model
        attr_reader :emotion
        attr_reader :speed
        attr_reader :engine
        attr_reader :params
        attr_reader :fillers
      end
    end
  end
end
