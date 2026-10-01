# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AmazonBedrockParams'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AmazonBedrockParams — generated read-side payload (schema.json $defs schema 'AmazonBedrockParams').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AmazonBedrockParams
        FIELDS = {
          'attention_timeout' => :object,
          'compact_conversation_time' => :string,
          'compact_strategy' => :string,
          'hard_stop_prompt' => :string,
          'hard_stop_time' => :string,
          'inactivity_timeout' => :object,
          'video_idle_file' => :string,
          'video_listening_file' => :string,
          'video_talking_file' => :string
        }.freeze

        attr_reader :attention_timeout, :compact_conversation_time, :compact_strategy, :hard_stop_prompt, :hard_stop_time, :inactivity_timeout, :video_idle_file, :video_listening_file, :video_talking_file
      end
    end
  end
end
# rubocop:enable Layout/LineLength
