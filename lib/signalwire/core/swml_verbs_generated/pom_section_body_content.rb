# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PomSectionBodyContent'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # PomSectionBodyContent — generated read-side payload (schema.json $defs schema 'PomSectionBodyContent').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class PomSectionBodyContent
        FIELDS = {
          'title' => :string,
          'subsections' => :array,
          'numbered' => :object,
          'numberedBullets' => :object,
          'body' => :string,
          'bullets' => :array,
        }.freeze

        attr_reader :title
        attr_reader :subsections
        attr_reader :numbered
        attr_reader :numberedBullets
        attr_reader :body
        attr_reader :bullets
      end
    end
  end
end
