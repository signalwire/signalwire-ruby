# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'detect_machine' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # DetectMachineConfig — generated read-side payload (flattened SWMLMethod verb 'detect_machine' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class DetectMachineConfig
        FIELDS = {
          'detect_message_end' => :object,
          'detectors' => :string,
          'end_silence_timeout' => :object,
          'initial_timeout' => :object,
          'machine_ready_timeout' => :object,
          'machine_voice_threshold' => :object,
          'machine_words_threshold' => :object,
          'status_url' => :string,
          'timeout' => :object,
          'tone' => :object,
          'wait' => :object
        }.freeze

        attr_reader :detect_message_end, :detectors, :end_silence_timeout, :initial_timeout, :machine_ready_timeout, :machine_voice_threshold, :machine_words_threshold, :status_url, :timeout, :tone, :wait
      end
    end
  end
end
# rubocop:enable Layout/LineLength
