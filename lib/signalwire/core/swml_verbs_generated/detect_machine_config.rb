# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'detect_machine' config

module SignalWire
  module Core
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
          'wait' => :object,
        }.freeze

        attr_reader :detect_message_end
        attr_reader :detectors
        attr_reader :end_silence_timeout
        attr_reader :initial_timeout
        attr_reader :machine_ready_timeout
        attr_reader :machine_voice_threshold
        attr_reader :machine_words_threshold
        attr_reader :status_url
        attr_reader :timeout
        attr_reader :tone
        attr_reader :wait
      end
    end
  end
end
