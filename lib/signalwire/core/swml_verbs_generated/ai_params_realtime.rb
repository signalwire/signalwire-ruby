# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'AiParamsRealtime'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # AiParamsRealtime — generated read-side payload (schema.json $defs schema 'AiParamsRealtime').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class AiParamsRealtime
        FIELDS = {
          'input_transcription' => :string,
          'local_vad' => :object,
          'local_vad_frame_ms' => :object,
          'local_vad_threshold' => :object,
          'noise_reduction' => :string,
          'packets_per_send' => :object,
          'reasoning_effort' => :string,
          'speed' => :object,
          'temperature' => :object,
          'tool_model' => :string,
          'vad_eagerness' => :string,
          'vad_prefix_padding_ms' => :object,
          'vad_silence_duration_ms' => :object,
          'vad_threshold' => :object,
          'vad_type' => :string,
          'voice' => :string
        }.freeze

        attr_reader :input_transcription, :local_vad, :local_vad_frame_ms, :local_vad_threshold, :noise_reduction, :packets_per_send, :reasoning_effort, :speed, :temperature, :tool_model, :vad_eagerness, :vad_prefix_padding_ms, :vad_silence_duration_ms, :vad_threshold, :vad_type, :voice
      end
    end
  end
end
# rubocop:enable Layout/LineLength
