# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# schema.json $defs schema 'RecordConfig'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwmlVerbsGenerated — namespace for this generated data-class tree.
    module SwmlVerbsGenerated
      # RecordConfig — generated read-side payload (schema.json $defs schema 'RecordConfig').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class RecordConfig
        FIELDS = {
          'format' => :object,
          'beep' => :object,
          'direction' => :object,
          'end_silence_timeout' => :object,
          'initial_timeout' => :object,
          'input_sensitivity' => :object,
          'max_length' => :object,
          'status_url' => :object,
          'stereo' => :object,
          'terminators' => :object
        }.freeze

        attr_reader :format, :beep, :direction, :end_silence_timeout, :initial_timeout, :input_sensitivity, :max_length, :status_url, :stereo, :terminators
      end
    end
  end
end
# rubocop:enable Layout/LineLength
