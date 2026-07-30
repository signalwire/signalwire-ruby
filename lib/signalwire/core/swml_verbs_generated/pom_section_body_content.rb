# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'PomSectionBodyContent'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # PomSectionBodyContent — generated read-side payload (schema.json $defs schema 'PomSectionBodyContent').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class PomSectionBodyContent
        FIELDS = {
          'title' => :string,
          'subsections' => :array,
          'numbered' => :object,
          'numberedBullets' => :object,
          'body' => :string,
          'bullets' => :array
        }.freeze

        attr_reader :title, :subsections, :numbered, :numberedBullets, :body, :bullets
      end
    end
  end
end
# rubocop:enable Naming/MethodName
