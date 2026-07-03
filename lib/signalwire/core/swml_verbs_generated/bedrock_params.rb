# frozen_string_literal: true

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
          'hard_stop_prompt' => :string,
        }.freeze

        attr_reader :attention_timeout
        attr_reader :hard_stop_time
        attr_reader :inactivity_timeout
        attr_reader :video_listening_file
        attr_reader :video_idle_file
        attr_reader :video_talking_file
        attr_reader :hard_stop_prompt
      end
    end
  end
end
