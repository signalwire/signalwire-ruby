# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'ContextPOMSteps'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # ContextPOMSteps — generated read-side payload (schema.json $defs schema 'ContextPOMSteps').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class ContextPOMSteps
        FIELDS = {
          'name' => :string,
          'step_criteria' => :string,
          'functions' => :array,
          'valid_contexts' => :array,
          'skip_user_turn' => :object,
          'end' => :boolean,
          'valid_steps' => :array,
          'pom' => :array,
        }.freeze

        attr_reader :name
        attr_reader :step_criteria
        attr_reader :functions
        attr_reader :valid_contexts
        attr_reader :skip_user_turn
        attr_reader :end
        attr_reader :valid_steps
        attr_reader :pom
      end
    end
  end
end
