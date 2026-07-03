# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'LanguagesWithFillers'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # LanguagesWithFillers — generated read-side payload (schema.json $defs schema 'LanguagesWithFillers').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
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
          'speech_fillers' => :array,
        }.freeze

        attr_reader :name
        attr_reader :code
        attr_reader :voice
        attr_reader :model
        attr_reader :emotion
        attr_reader :speed
        attr_reader :engine
        attr_reader :params
        attr_reader :function_fillers
        attr_reader :speech_fillers
      end
    end
  end
end
