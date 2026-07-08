# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'BedrockParams'

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # BedrockParams — generated read-side payload (schema.json $defs schema 'BedrockParams').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class BedrockParams
        FIELDS = {
          'attention_timeout' => :object,
          'hard_stop_time' => :object,
          'inactivity_timeout' => :object,
          'video_listening_file' => :string,
          'video_idle_file' => :string,
          'video_talking_file' => :string,
          'hard_stop_prompt' => :string
        }.freeze

        attr_reader :attention_timeout, :hard_stop_time, :inactivity_timeout, :video_listening_file, :video_idle_file, :video_talking_file, :hard_stop_prompt
      end
    end
  end
end
# rubocop:enable Layout/LineLength
