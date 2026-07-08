# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'StringProperty'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # StringProperty — generated read-side payload (schema.json $defs schema 'StringProperty').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class StringProperty
        FIELDS = {
          'description' => :string,
          'nullable' => :object,
          'type' => :string,
          'enum' => :array,
          'default' => :string,
          'pattern' => :string,
          'format' => :object
        }.freeze

        attr_reader :description, :nullable, :type, :enum, :default, :pattern, :format
      end
    end
  end
end
