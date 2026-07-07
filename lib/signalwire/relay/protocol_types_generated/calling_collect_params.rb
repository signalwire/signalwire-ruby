# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# RELAY method 'calling.collect', params

module SignalWire
  module Relay
    module ProtocolTypesGenerated
      # CallingCollectParams — generated data type (RELAY method 'calling.collect', params).
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # No reader/writer methods and no initialize — a method-less type the
      # reference records method-less on both surface and signatures.
      class CallingCollectParams
        FIELDS = {
          'call_id' => :string,
          'continue' => :boolean,
          'continuous' => :boolean,
          'control_id' => :string,
          'digits' => :object,
          'initial_timeout' => :number,
          'node_id' => :string,
          'partial_results' => :boolean,
          'send_start_of_input' => :boolean,
          'speech' => :object,
          'start_input_timers' => :boolean
        }.freeze
      end
    end
  end
end
