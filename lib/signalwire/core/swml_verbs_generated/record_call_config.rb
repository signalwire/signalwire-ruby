# frozen_string_literal: true

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'record_call' config

module SignalWire
  module Core
    module SwmlVerbsGenerated
      # RecordCallConfig — generated read-side payload (flattened SWMLMethod verb 'record_call' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # A zero-arg reader per field mirrors the reference's recorded
      # accessors (dropped on the SURFACE by the enumerator — method-less there).
      class RecordCallConfig
        FIELDS = {
          'control_id' => :string,
          'stereo' => :object,
          'format' => :object,
          'direction' => :object,
          'terminators' => :string,
          'beep' => :object,
          'input_sensitivity' => :object,
          'initial_timeout' => :object,
          'end_silence_timeout' => :object,
          'max_length' => :object,
          'status_url' => :string,
        }.freeze

        attr_reader :control_id
        attr_reader :stereo
        attr_reader :format
        attr_reader :direction
        attr_reader :terminators
        attr_reader :beep
        attr_reader :input_sensitivity
        attr_reader :initial_timeout
        attr_reader :end_silence_timeout
        attr_reader :max_length
        attr_reader :status_url
      end
    end
  end
end
