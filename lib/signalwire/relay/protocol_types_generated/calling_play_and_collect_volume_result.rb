# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.play_and_collect.volume', result

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingPlayAndCollectVolumeResult — generated data type (RELAY method 'calling.play_and_collect.volume', result).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingPlayAndCollectVolumeResult
        FIELDS = {
          'call_id' => :string,
          'code' => :string,
          'control_id' => :string,
          'data' => :any,
          'message' => :string
        }.freeze
      end
    end
  end
end
# rubocop:enable Layout/LineLength
