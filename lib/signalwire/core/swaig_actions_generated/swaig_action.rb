# frozen_string_literal: true

# Spec-derived generated surface: wire keys, folded schema constants, and per-schema
# CRUD/data-class size are preserved verbatim; these cops are pruned per file by the
# generator's rubocop pass to exactly those that fire.
# rubocop:disable Layout/LineLength, Naming/MethodName

# Code generated; DO NOT EDIT. Regenerate with the matching scripts/generate_*.py.
#
# swaig-response components/schemas 'SwaigAction'

module SignalWire
  # SignalWire::Core — namespace for this generated data-class tree.
  module Core
    # SignalWire::Core::SwaigActionsGenerated — namespace for this generated data-class tree.
    module SwaigActionsGenerated
      # SwaigAction — generated read-side payload (swaig-response components/schemas 'SwaigAction').
      #
      # Frozen FIELDS maps each snake wire key to its JSON type symbol.
      # Each field also has a zero-arg reader, so a decoded payload can be
      # accessed by name rather than by wire key.
      class SwaigAction
        FIELDS = {
          'SWML' => :object,
          'add_dynamic_hints' => :array,
          'back_to_back_functions' => :object,
          'change_context' => :string,
          'change_step' => :string,
          'clear_dynamic_hints' => :boolean,
          'context_switch' => :object,
          'end_of_speech_timeout' => :integer,
          'extensive_data' => :boolean,
          'functions_on_speaker_timeout' => :boolean,
          'hangup' => :boolean,
          'hold' => :object,
          'playback_bg' => :object,
          'replace_in_history' => :object,
          'say' => :string,
          'set_global_data' => :object,
          'set_meta_data' => :object,
          'settings' => :object,
          'speech_event_timeout' => :integer,
          'stop' => :boolean,
          'stop_playback_bg' => :boolean,
          'toggle_functions' => :array,
          'transfer' => :object,
          'unset_global_data' => :object,
          'unset_meta_data' => :object,
          'user_event' => :object,
          'user_input' => :string,
          'wait_for_user' => :object
        }.freeze

        attr_reader :SWML, :add_dynamic_hints, :back_to_back_functions, :change_context, :change_step, :clear_dynamic_hints, :context_switch, :end_of_speech_timeout, :extensive_data, :functions_on_speaker_timeout, :hangup, :hold, :playback_bg, :replace_in_history, :say, :set_global_data, :set_meta_data, :settings, :speech_event_timeout, :stop, :stop_playback_bg, :toggle_functions, :transfer, :unset_global_data, :unset_meta_data, :user_event, :user_input, :wait_for_user
      end
    end
  end
end
# rubocop:enable Layout/LineLength, Naming/MethodName
