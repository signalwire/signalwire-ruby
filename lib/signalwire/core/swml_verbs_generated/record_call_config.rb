# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# flattened SWMLMethod verb 'record_call' config

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # RecordCallConfig — generated read-side payload (flattened SWMLMethod verb 'record_call' config).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
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
          'status_url' => :string
        }.freeze

        attr_reader :control_id, :stereo, :format, :direction, :terminators, :beep, :input_sensitivity, :initial_timeout, :end_silence_timeout, :max_length, :status_url
      end
    end
  end
end
# rubocop:enable Layout/LineLength
