# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PlayWithURL'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PlayWithURL — generated read-side payload (schema.json $defs schema 'PlayWithURL').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PlayWithURL
        FIELDS = {
          'auto_answer' => :object,
          'volume' => :object,
          'say_voice' => :string,
          'say_language' => :string,
          'say_gender' => :string,
          'status_url' => :string,
          'url' => :object,
        }.freeze

        attr_reader :auto_answer
        attr_reader :volume
        attr_reader :say_voice
        attr_reader :say_language
        attr_reader :say_gender
        attr_reader :status_url
        attr_reader :url
      end
    end
  end
end
