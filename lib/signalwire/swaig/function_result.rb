# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Swaig — the SWAIG function-call surface: results, actions and typed payloads.
  module Swaig
    # ------------------------------------------------------------------
    # Closed-set vocabularies for SWAIG verbs.
    #
    # Each constant's value IS the wire string, so a caller may pass the
    # bare string (parity with the Python reference, which takes a plain
    # +str+) or the named constant interchangeably — they are literally
    # the same object. The +FunctionResult+ validators below reference
    # these +ALL+ arrays directly, so the named set and the validated set
    # can never drift apart (single source of truth).
    #
    # Idiom note: this mirrors +SignalWire::Relay+'s constants module
    # (flat +NAME = 'value'+ string constants grouped into a frozen +ALL+
    # array). These are SWAIG (SWML-verb) vocabularies and are deliberately
    # kept DISTINCT from the RELAY codecs/directions — see the warnings on
    # each module.
    # ------------------------------------------------------------------

    # Audio container format for the +record_call+ verb.
    module RecordFormat
      WAV = 'wav'
      MP3 = 'mp3'
      MP4 = 'mp4'

      # Every valid +record_call+ format, in wire order.
      ALL = [WAV, MP3, MP4].freeze
    end

    # Channel selection for the +record_call+ verb.
    #
    # DISTINCT from {TapDirection}: record uses +listen+, tap uses +hear+.
    # Never share a constant between the two — Python validates two
    # different lists, and conflating them is a known bug generator.
    module RecordDirection
      SPEAK  = 'speak'
      LISTEN = 'listen'
      BOTH   = 'both'

      # Every valid +record_call+ direction, in wire order.
      ALL = [SPEAK, LISTEN, BOTH].freeze
    end

    # Channel selection for the +tap+ verb.
    #
    # DISTINCT from {RecordDirection}: tap uses +hear+, record uses
    # +listen+. Also distinct from the RELAY play/record/tap direction
    # vocabulary. Never unify.
    module TapDirection
      SPEAK = 'speak'
      HEAR  = 'hear'
      BOTH  = 'both'

      # Every valid +tap+ direction, in wire order.
      ALL = [SPEAK, HEAR, BOTH].freeze
    end

    # RTP payload codec for the +tap+ verb.
    #
    # This is the 2-value SWAIG tap codec only. It is DELIBERATELY NOT the
    # broader RELAY +stream+/+connect+ device-codec superset (which adds
    # OPUS/G729/G722/VP8/H264). Never reuse this constant there.
    module Codec
      PCMU = 'PCMU'
      PCMA = 'PCMA'

      # Every valid +tap+ codec, in wire order.
      ALL = [PCMU, PCMA].freeze
    end

    # Response builder that tool handlers return.
    # All mutating methods return +self+ for fluent chaining.
    #
    #   result = FunctionResult.new("Found your order")
    #     .update_global_data("order_id" => "12345")
    #     .say("Let me look that up")
    #
    # The result object has three main components:
    #   1. response     - Text the AI should say back to the user
    #   2. action       - List of structured actions to execute
    #   3. post_process - Whether to let AI take another turn before executing actions
    #
    class FunctionResult
      # Default +ai_response+ for +pay+ (extracted to keep the signature line
      # within length limits; value is wire-load-bearing — mirrors Python).
      PAY_DEFAULT_AI_RESPONSE =
        'The payment status is ${pay_result}, do not mention anything else ' \
        'about collecting payment if successful.'

      # Enum validations for +join_conference+, in Python's raise order.
      # Each entry: [opts_key, allowed_values, error_message].
      JOIN_CONFERENCE_ENUMS = [
        [:beep, %w[true false onEnter onExit],
         "beep must be one of ['true', 'false', 'onEnter', 'onExit']"],
        [:record, %w[do-not-record record-from-start],
         "record must be one of ['do-not-record', 'record-from-start']"],
        [:trim, %w[trim-silence do-not-trim],
         "trim must be one of ['trim-silence', 'do-not-trim']"],
        [:status_callback_method, %w[GET POST],
         "status_callback_method must be one of ['GET', 'POST']"],
        [:recording_status_callback_method, %w[GET POST],
         "recording_status_callback_method must be one of ['GET', 'POST']"]
      ].freeze

      # Spec for the non-default conference params, in exact wire-key order.
      # Each entry: [wire_key, opts_key, ->(value) { include? }]. Driving the
      # build off this table keeps key insertion order byte-identical to the
      # Python reference while staying flat (one loop, not 18 branches).
      JOIN_CONFERENCE_PARAM_SPEC = [
        ['muted',            :muted,            ->(v) { v }],
        ['beep',             :beep,             ->(v) { v != 'true' }],
        ['start_on_enter',   :start_on_enter,   :!.to_proc],
        ['end_on_exit',      :end_on_exit,      ->(v) { v }],
        ['wait_url',         :wait_url,         ->(v) { v }],
        ['max_participants', :max_participants, ->(v) { v != 250 }],
        ['record',           :record,           ->(v) { v != 'do-not-record' }],
        ['region',           :region,           ->(v) { v }],
        ['trim',             :trim,             ->(v) { v != 'trim-silence' }],
        ['coach',            :coach,            ->(v) { v }],
        ['status_callback_event',            :status_callback_event,            ->(v) { v }],
        ['status_callback',                  :status_callback,                  ->(v) { v }],
        ['status_callback_method',           :status_callback_method,           ->(v) { v != 'POST' }],
        ['recording_status_callback',        :recording_status_callback,        ->(v) { v }],
        ['recording_status_callback_method', :recording_status_callback_method, ->(v) { v != 'POST' }],
        ['recording_status_callback_event',  :recording_status_callback_event,  ->(v) { v != 'completed' }],
        ['result',                           :result,                           ->(v) { v }]
      ].freeze

      # response= / post_process= are defined explicitly below (they delegate to
      # set_response / set_post_process); declaring them here too via
      # attr_accessor would define the writers twice (Lint/DuplicateMethods).
      attr_reader :response, :post_process
      attr_accessor :action

      # @param response [String, nil] text the AI speaks back to the user
      # @param post_process [Boolean] whether to let AI take another turn before executing actions
      def initialize(response = nil, post_process: false)
        @response = response || ''
        @action = []
        @post_process = post_process
      end

      # ------------------------------------------------------------------
      # Core mutators
      # ------------------------------------------------------------------

      # Set the natural-language response text.
      # @return [self]
      def set_response(text)
        @response = text
        self
      end

      # Enable / disable post-processing.
      # @return [self]
      def set_post_process(val)
        @post_process = val
        self
      end

      # Add a single structured action.
      # @param name [String] action key
      # @param data [Object] action value
      # @return [self]
      def add_action(name, data)
        @action << { name => data }
        self
      end

      # Add multiple structured actions at once.
      # @param actions [Array<Hash>]
      # @return [self]
      def add_actions(actions)
        @action.concat(actions)
        self
      end

      # ==================================================================
      # Call Control
      # ==================================================================

      # Connect / transfer the call to another destination.
      #
      # @param destination [String] phone number, SIP address, etc.
      # @param final [Boolean] permanent (+true+) or temporary (+false+) transfer
      # @param from_addr [String, nil] optional caller-ID override
      # @return [self]
      def connect(destination, final: true, from_addr: nil)
        connect_params = { 'to' => destination }
        connect_params['from'] = from_addr if from_addr

        @action << {
          'SWML' => {
            'sections' => { 'main' => [{ 'connect' => connect_params }] },
            'version' => '1.0.0'
          },
          'transfer' => final.to_s
        }
        self
      end

      # Transfer via SWML with an AI response when transfer completes.
      #
      # @param dest [String] destination URL for the transfer
      # @param ai_response [String] message AI says when transfer completes
      # @param final [Boolean] permanent or temporary transfer
      # @return [self]
      def swml_transfer(dest, ai_response, final: true)
        main = [
          { 'set' => { 'ai_response' => ai_response } },
          { 'transfer' => { 'dest' => dest } }
        ]
        @action << {
          'SWML' => { 'version' => '1.0.0', 'sections' => { 'main' => main } },
          'transfer' => final.to_s
        }
        self
      end

      # Terminate the call.
      # @return [self]
      def hangup
        add_action('hangup', true)
      end

      # Put the call on hold.
      # @param timeout [Integer] seconds, clamped to 0..900
      # @return [self]
      def hold(timeout = 300)
        timeout = timeout.clamp(0, 900)
        add_action('hold', timeout)
      end

      # Control how the agent waits for user input.
      #
      # @param enabled [Boolean, nil] enable/disable waiting
      # @param timeout [Integer, nil] seconds to wait
      # @param answer_first [Boolean] special "answer_first" mode
      # @return [self]
      def wait_for_user(enabled: nil, timeout: nil, answer_first: false)
        wait_value = if answer_first
                       'answer_first'
                     elsif timeout
                       timeout
                     elsif !enabled.nil?
                       enabled
                     else
                       true
                     end
        add_action('wait_for_user', wait_value)
      end

      # Stop agent execution.
      # @return [self]
      def stop
        add_action('stop', true)
      end

      # ==================================================================
      # State & Data Management
      # ==================================================================

      # Update global agent data variables.
      # @param data [Hash] key-value pairs to set/update
      # @return [self]
      def update_global_data(data)
        add_action('set_global_data', data)
      end

      # Remove global agent data variables.
      # @param keys [String, Array<String>] key(s) to remove
      # @return [self]
      def remove_global_data(keys)
        add_action('unset_global_data', keys)
      end

      # Set metadata scoped to current function's meta_data_token.
      # @param data [Hash]
      # @return [self]
      def set_metadata(data)
        add_action('set_meta_data', data)
      end

      # Remove metadata from current function's scope.
      # @param keys [String, Array<String>]
      # @return [self]
      def remove_metadata(keys)
        add_action('unset_meta_data', keys)
      end

      # Send a user event through SWML.
      # @param event_data [Hash] event payload
      # @return [self]
      def swml_user_event(event_data)
        swml_action = {
          'sections' => {
            'main' => [{
              'user_event' => { 'event' => event_data }
            }]
          },
          'version' => '1.0.0'
        }
        add_action('SWML', swml_action)
      end

      # Change the conversation step.
      # @param step_name [String]
      # @return [self]
      def swml_change_step(step_name)
        add_action('change_step', step_name)
      end

      # Change the conversation context.
      # @param context_name [String]
      # @return [self]
      def swml_change_context(context_name)
        add_action('change_context', context_name)
      end

      # Switch agent context/prompt during conversation.
      #
      # When only +system_prompt+ is provided and all flags are false, emits
      # a simple string context switch. Otherwise emits the full object form.
      #
      # @param system_prompt [String, nil]
      # @param user_prompt [String, nil]
      # @param consolidate [Boolean]
      # @param full_reset [Boolean]
      # @param isolated [Boolean]
      # @return [self]
      def switch_context(system_prompt: nil, user_prompt: nil,
                         consolidate: false, full_reset: false, isolated: false)
        flags_unset = !user_prompt && !consolidate && !full_reset && !isolated
        return add_action('context_switch', system_prompt) if system_prompt && flags_unset

        context_data = build_context_switch_data(system_prompt, user_prompt, consolidate,
                                                 full_reset, isolated)
        add_action('context_switch', context_data)
      end

      # Replace the tool_call + result pair in conversation history.
      #
      # @param text [String, true] replacement text, or +true+ to remove entirely
      # @return [self]
      def replace_in_history(text = true)
        add_action('replace_in_history', text)
      end

      # ==================================================================
      # Media Control
      # ==================================================================

      # Make the agent speak specific text.
      # @param text [String]
      # @return [self]
      def say(text)
        add_action('say', text)
      end

      # Play audio/video file in the background.
      #
      # @param filename [String] audio/video filename or URL
      # @param wait [Boolean] suppress attention-getting behaviour during playback
      # @return [self]
      def play_background_file(filename, wait: false)
        if wait
          add_action('playback_bg', { 'file' => filename, 'wait' => true })
        else
          add_action('playback_bg', filename)
        end
      end

      # Stop currently playing background file.
      # @return [self]
      def stop_background_file
        add_action('stop_playback_bg', true)
      end

      # Start background call recording via SWML.
      #
      # @param control_id [String, nil]
      # @param stereo [Boolean]
      # @param format [String] "wav", "mp3", or "mp4"
      # @param direction [String] "speak", "listen", or "both"
      # @return [self]
      def record_call(control_id: nil, stereo: false, format: RecordFormat::WAV,
                      direction: RecordDirection::BOTH, terminators: nil, beep: false,
                      input_sensitivity: 44.0, initial_timeout: nil,
                      end_silence_timeout: nil, max_length: nil, status_url: nil)
        validate_record_call!(format, direction)

        record_params = { 'stereo' => stereo, 'format' => format, 'direction' => direction,
                          'beep' => beep, 'input_sensitivity' => input_sensitivity }
        assign_present(record_params,
                       'control_id' => control_id, 'terminators' => terminators,
                       'initial_timeout' => initial_timeout,
                       'end_silence_timeout' => end_silence_timeout,
                       'max_length' => max_length, 'status_url' => status_url)

        execute_swml(swml_envelope('record_call', record_params))
      end

      # Stop an active background call recording.
      # @param control_id [String, nil]
      # @return [self]
      def stop_record_call(control_id: nil)
        stop_params = {}
        stop_params['control_id'] = control_id if control_id

        execute_swml(swml_envelope('stop_record_call', stop_params))
      end

      # ==================================================================
      # Speech & AI Configuration
      # ==================================================================

      # Add dynamic speech recognition hints.
      # @param hints [Array<String, Hash>]
      # @return [self]
      def add_dynamic_hints(hints)
        add_action('add_dynamic_hints', hints)
      end

      # Clear all dynamic speech recognition hints.
      # @return [self]
      def clear_dynamic_hints
        @action << { 'clear_dynamic_hints' => {} }
        self
      end

      # Adjust end-of-speech timeout.
      # @param milliseconds [Integer]
      # @return [self]
      def set_end_of_speech_timeout(milliseconds)
        add_action('end_of_speech_timeout', milliseconds)
      end

      # Adjust speech event timeout.
      # @param milliseconds [Integer]
      # @return [self]
      def set_speech_event_timeout(milliseconds)
        add_action('speech_event_timeout', milliseconds)
      end

      # Enable / disable specific SWAIG functions.
      # @param toggles [Array<Hash>] each with "function" and "active" keys
      # @return [self]
      def toggle_functions(toggles)
        add_action('toggle_functions', toggles)
      end

      # Enable function calls on speaker timeout.
      # @param enabled [Boolean]
      # @return [self]
      def enable_functions_on_timeout(enabled = true)
        add_action('functions_on_speaker_timeout', enabled)
      end

      # Send full data to LLM for this turn only.
      # @param enabled [Boolean]
      # @return [self]
      def enable_extensive_data(enabled = true)
        add_action('extensive_data', enabled)
      end

      # Update agent runtime settings (temperature, top_p, etc.).
      # @param settings [Hash]
      # @return [self]
      def update_settings(settings)
        add_action('settings', settings)
      end

      # ==================================================================
      # Advanced Features
      # ==================================================================

      # Execute SWML content with optional transfer.
      #
      # @param swml_content [Hash, String] SWML data structure or JSON string
      # @param transfer [Boolean] whether call should exit agent after execution
      # @return [self]
      def execute_swml(swml_content, transfer: false)
        swml_data = coerce_swml_content(swml_content)
        swml_data['transfer'] = 'true' if transfer
        add_action('SWML', swml_data)
      end

      # Join an ad-hoc audio conference via SWML.
      #
      # @param name [String] conference name (required)
      # @return [self]
      def join_conference(name, muted: false, beep: 'true',
                          start_on_enter: true, end_on_exit: false,
                          wait_url: nil, max_participants: 250,
                          record: 'do-not-record', region: nil,
                          trim: 'trim-silence', coach: nil,
                          status_callback_event: nil, status_callback: nil,
                          status_callback_method: 'POST',
                          recording_status_callback: nil,
                          recording_status_callback_method: 'POST',
                          recording_status_callback_event: 'completed',
                          result: nil)
        opts = {
          muted: muted, beep: beep, start_on_enter: start_on_enter, end_on_exit: end_on_exit,
          wait_url: wait_url, max_participants: max_participants, record: record, region: region,
          trim: trim, coach: coach, status_callback_event: status_callback_event,
          status_callback: status_callback, status_callback_method: status_callback_method,
          recording_status_callback: recording_status_callback,
          recording_status_callback_method: recording_status_callback_method,
          recording_status_callback_event: recording_status_callback_event, result: result
        }
        join_conference_action(name, opts)
      end

      # Join a RELAY room via SWML.
      # @param name [String]
      # @return [self]
      def join_room(name)
        execute_swml(swml_envelope('join_room', { 'name' => name }))
      end

      # Send SIP REFER via SWML.
      # @param to_uri [String]
      # @return [self]
      def sip_refer(to_uri)
        execute_swml(swml_envelope('sip_refer', { 'to_uri' => to_uri }))
      end

      # Start a background call tap via SWML.
      #
      # @param uri [String] destination URI (rtp://, ws://, wss://)
      # @param control_id [String, nil]
      # @param direction [String] "speak", "hear", or "both"
      # @param codec [String] "PCMU" or "PCMA"
      # @param rtp_ptime [Integer] packetization time in ms
      # @param status_url [String, nil]
      # @return [self]
      def tap(uri, control_id: nil, direction: TapDirection::BOTH, codec: Codec::PCMU,
              rtp_ptime: 20, status_url: nil)
        validate_tap!(direction, codec, rtp_ptime)

        tap_params = { 'uri' => uri }
        tap_params['control_id'] = control_id if control_id
        tap_params['direction']  = direction  if direction != TapDirection::BOTH
        tap_params['codec']      = codec      if codec != Codec::PCMU
        tap_params['rtp_ptime']  = rtp_ptime  if rtp_ptime != 20
        tap_params['status_url'] = status_url if status_url

        execute_swml(swml_envelope('tap', tap_params))
      end

      # Stop an active tap stream via SWML.
      # @param control_id [String, nil]
      # @return [self]
      def stop_tap(control_id: nil)
        stop_params = {}
        stop_params['control_id'] = control_id if control_id

        execute_swml(swml_envelope('stop_tap', stop_params))
      end

      # Send an SMS message via SWML.
      #
      # @param to_number [String] E.164 phone number
      # @param from_number [String] E.164 phone number
      # @param body [String, nil]
      # @param media [Array<String>, nil]
      # @param tags [Array<String>, nil]
      # @param region [String, nil]
      # @return [self]
      def send_sms(to_number:, from_number:, body: nil, media: nil,
                   tags: nil, region: nil)
        raise ArgumentError, 'Either body or media must be provided' if sms_blank?(body) && sms_blank?(media)

        sms_params = {
          'to_number' => to_number,
          'from_number' => from_number
        }
        sms_params['body']   = body   unless sms_blank?(body)
        sms_params['media']  = media  unless sms_blank?(media)
        sms_params['tags']   = tags   unless sms_blank?(tags)
        sms_params['region'] = region if region

        execute_swml(swml_envelope('send_sms', sms_params))
      end

      # Process payment using SWML pay action.
      #
      # @param payment_connector_url [String] URL to make payment requests to
      # @param input_method [String] "dtmf" or "voice"
      # @return [self]
      def pay(payment_connector_url:, input_method: 'dtmf',
              status_url: nil, payment_method: 'credit-card',
              timeout: 5, max_attempts: 1, security_code: true,
              postal_code: true, min_postal_code_length: 0,
              token_type: 'reusable', charge_amount: nil,
              currency: 'usd', language: 'en-US', voice: 'woman',
              description: nil, valid_card_types: 'visa mastercard amex',
              parameters: nil, prompts: nil,
              ai_response: PAY_DEFAULT_AI_RESPONSE)
        pay_params = build_pay_params(
          payment_connector_url: payment_connector_url, input_method: input_method,
          payment_method: payment_method, timeout: timeout, max_attempts: max_attempts,
          security_code: security_code, min_postal_code_length: min_postal_code_length,
          token_type: token_type, currency: currency, language: language, voice: voice,
          valid_card_types: valid_card_types, postal_code: postal_code,
          status_url: status_url, charge_amount: charge_amount, description: description,
          parameters: parameters, prompts: prompts
        )
        execute_swml(pay_swml_doc(ai_response, pay_params))
      end

      # ==================================================================
      # RPC Actions
      # ==================================================================

      # Execute a generic RPC method via SWML.
      #
      # @param method [String] RPC method name
      # @param params [Hash, nil]
      # @param call_id [String, nil]
      # @param node_id [String, nil]
      # @return [self]
      def execute_rpc(method, params: nil, call_id: nil, node_id: nil)
        rpc_params = { 'method' => method }
        rpc_params['call_id'] = call_id if call_id
        rpc_params['node_id'] = node_id if node_id
        rpc_params['params']  = params  if params && !params.empty?

        execute_swml(swml_envelope('execute_rpc', rpc_params))
      end

      # Dial out to a number via RPC.
      #
      # @param to_number [String] E.164 phone number
      # @param from_number [String] E.164 caller ID
      # @param dest_swml [String] SWML URL for the outbound leg
      # @param device_type [String]
      # @return [self]
      def rpc_dial(to_number:, from_number:, dest_swml:, device_type: 'phone')
        device = { 'type' => device_type,
                   'params' => { 'to_number' => to_number, 'from_number' => from_number } }
        execute_rpc('dial', params: { 'devices' => device, 'dest_swml' => dest_swml })
      end

      # Inject a message into an AI agent on another call.
      #
      # @param call_id [String]
      # @param message_text [String]
      # @param role [String]
      # @return [self]
      def rpc_ai_message(call_id, message_text, role: 'system')
        execute_rpc(
          'ai_message',
          call_id: call_id,
          params: {
            'role' => role,
            'message_text' => message_text
          }
        )
      end

      # Unhold another call via RPC.
      # @param call_id [String]
      # @return [self]
      def rpc_ai_unhold(call_id)
        execute_rpc('ai_unhold', call_id: call_id, params: {})
      end

      # Queue simulated user input.
      # @param text [String]
      # @return [self]
      def simulate_user_input(text)
        add_action('user_input', text)
      end

      # ==================================================================
      # Payment helpers (class methods)
      # ==================================================================

      # Create a payment prompt structure for use with +pay+.
      #
      # @param for_situation [String] e.g. "payment-card-number"
      # @param actions [Array<Hash>] actions with "type" and "phrase" keys
      # @param card_type [String, nil]
      # @param error_type [String, nil]
      # @return [Hash]
      def self.create_payment_prompt(for_situation, actions, card_type: nil, error_type: nil)
        prompt = {
          'for' => for_situation,
          'actions' => actions
        }
        prompt['card_type']  = card_type  if card_type
        prompt['error_type'] = error_type if error_type
        prompt
      end

      # Create a payment action for use inside payment prompts.
      #
      # @param action_type [String] "Say" or "Play"
      # @param phrase [String]
      # @return [Hash]
      def self.create_payment_action(action_type, phrase)
        { 'type' => action_type, 'phrase' => phrase }
      end

      # Create a payment parameter for use with +pay+.
      #
      # @param name [String]
      # @param value [String]
      # @return [Hash]
      def self.create_payment_parameter(name, value)
        { 'name' => name, 'value' => value }
      end

      # ==================================================================
      # Serialization
      # ==================================================================

      # Convert to the Hash structure expected by SWAIG.
      #
      # Rules:
      # - +response+ always included (string)
      # - +action+ only included if at least one action exists
      # - +post_process+ only included if +true+ and actions exist
      #
      # @return [Hash]
      def to_h
        result = {}
        actions_present = actions?

        result['response'] = @response if response?
        result['action']   = @action   if actions_present
        result['post_process'] = true if @post_process && actions_present

        # Ensure at least one of response or action is present
        result['response'] = 'Action completed.' if result.empty?

        result
      end

      # @return [String] JSON representation
      def to_json(*)
        to_h.to_json(*)
      end

      # --- Idiomatic Ruby accessors (additive aliases over set_* originals) ---
      def end_of_speech_timeout=(value)
        set_end_of_speech_timeout(value)
      end

      # Attach arbitrary metadata to the result. Writer form of {#set_metadata};
      # returns the assigned value, not self.
      def metadata=(value)
        set_metadata(value)
      end

      # Whether the AI speaks its response BEFORE running this result's actions
      # (true) or after. Writer form of {#set_post_process}.
      def post_process=(value)
        set_post_process(value)
      end

      # The text the model receives as this tool's answer. Writer form of
      # {#set_response}.
      def response=(value)
        set_response(value)
      end

      # Milliseconds to wait for a speech event before proceeding. Writer form of
      # {#set_speech_event_timeout}.
      def speech_event_timeout=(value)
        set_speech_event_timeout(value)
      end

      private

      # @api private — reject a record_call whose format is not wav/mp3/mp4 or whose
      # direction is not speak/listen/both, so a bad value fails here rather than
      # being rejected mid-call by the server.
      #
      # @raise [ArgumentError] naming the offending field
      def validate_record_call!(format, direction)
        raise ArgumentError, "format must be 'wav', 'mp3', or 'mp4'" unless RecordFormat::ALL.include?(format)
        return if RecordDirection::ALL.include?(direction)

        raise ArgumentError, "direction must be 'speak', 'listen', or 'both'"
      end

      # @api private — reject a tap whose direction is not speak/hear/both, whose
      # codec is not PCMU/PCMA, or whose packetization time is not positive.
      #
      # @raise [ArgumentError] naming the offending field
      def validate_tap!(direction, codec, rtp_ptime)
        raise ArgumentError, "direction must be 'speak', 'hear', or 'both'" unless TapDirection::ALL.include?(direction)
        raise ArgumentError, "codec must be 'PCMU' or 'PCMA'" unless Codec::ALL.include?(codec)
        raise ArgumentError, 'rtp_ptime must be positive' unless rtp_ptime.positive?
      end

      # Assign each truthy value into +target+ under its wire key, in the
      # given hash's insertion order (preserving wire key order).
      def assign_present(target, pairs)
        pairs.each { |key, value| target[key] = value if value }
        target
      end

      # Build the object-form +context_switch+ payload (key order matches
      # the Python reference: system_prompt, user_prompt, consolidate,
      # full_reset, isolated).
      def build_context_switch_data(system_prompt, user_prompt, consolidate, full_reset, isolated)
        context_data = {}
        context_data['system_prompt'] = system_prompt if system_prompt
        context_data['user_prompt']   = user_prompt   if user_prompt
        context_data['consolidate']   = true          if consolidate
        context_data['full_reset']    = true          if full_reset
        context_data['isolated']      = true          if isolated
        context_data
      end

      # SWML doc for +pay+: a +set ai_response+ step followed by the +pay+
      # verb (two-element main section; not the single-verb envelope).
      def pay_swml_doc(ai_response, pay_params)
        {
          'version' => '1.0.0',
          'sections' => {
            'main' => [
              { 'set' => { 'ai_response' => ai_response } },
              { 'pay' => pay_params }
            ]
          }
        }
      end

      # Build the +pay+ verb params. Key order (the fixed block, then
      # postal_code, then the optional tail) is wire-load-bearing and
      # identical to the Python reference.
      def build_pay_params(payment_connector_url:, input_method:, payment_method:, timeout:,
                           max_attempts:, security_code:, min_postal_code_length:, token_type:,
                           currency:, language:, voice:, valid_card_types:, postal_code:,
                           status_url:, charge_amount:, description:, parameters:, prompts:)
        pay_params = pay_fixed_params(
          payment_connector_url: payment_connector_url, input_method: input_method,
          payment_method: payment_method, timeout: timeout, max_attempts: max_attempts,
          security_code: security_code, min_postal_code_length: min_postal_code_length,
          token_type: token_type, currency: currency, language: language, voice: voice,
          valid_card_types: valid_card_types, postal_code: postal_code
        )
        assign_present(pay_params, 'status_url' => status_url, 'charge_amount' => charge_amount,
                                   'description' => description, 'parameters' => parameters,
                                   'prompts' => prompts)
      end

      # The always-present +pay+ params, in wire-key order.
      def pay_fixed_params(payment_connector_url:, input_method:, payment_method:, timeout:,
                           max_attempts:, security_code:, min_postal_code_length:, token_type:,
                           currency:, language:, voice:, valid_card_types:, postal_code:)
        {
          'payment_connector_url' => payment_connector_url, 'input' => input_method,
          'payment_method' => payment_method, 'timeout' => timeout.to_s,
          'max_attempts' => max_attempts.to_s, 'security_code' => security_code.to_s,
          'min_postal_code_length' => min_postal_code_length.to_s, 'token_type' => token_type,
          'currency' => currency, 'language' => language, 'voice' => voice,
          'valid_card_types' => valid_card_types,
          'postal_code' => postal_code.is_a?(String) ? postal_code : postal_code.to_s
        }
      end

      # Normalize +execute_swml+ input to a Hash: parse JSON strings (falling
      # back to a raw_swml wrapper), dup Hashes, else require #to_h.
      def coerce_swml_content(swml_content)
        case swml_content
        when String then parse_swml_string(swml_content)
        when Hash   then swml_content.dup
        else
          unless swml_content.respond_to?(:to_h)
            raise TypeError, 'swml_content must be a String, Hash, or respond to #to_h'
          end

          swml_content.to_h
        end
      end

      # Parse a JSON SWML string, falling back to a raw_swml wrapper.
      def parse_swml_string(swml_content)
        JSON.parse(swml_content)
      rescue JSON::ParserError
        { 'raw_swml' => swml_content }
      end

      # Wrap a single SWAIG verb + params in the standard SWML envelope.
      # Key order (version, sections → main → [{verb => params}]) is
      # wire-load-bearing and identical to the Python reference.
      def swml_envelope(verb, params)
        {
          'version' => '1.0.0',
          'sections' => { 'main' => [{ verb => params }] }
        }
      end

      # @api private — whether any action has been queued on this result.
      #
      # @return [Boolean]
      def actions?
        @action && !@action.empty?
      end

      # @api private — whether a non-empty response text has been set.
      #
      # @return [Boolean]
      def response?
        @response && !@response.empty?
      end

      # nil, or responds to #empty? and is empty (mirrors the Python
      # truthiness checks used by +send_sms+).
      def sms_blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      # @api private — the join_conference action. When every option is at its
      # default the wire value collapses to the bare conference NAME rather than a
      # params object, matching the reference's emitted shape.
      def join_conference_action(name, opts)
        validate_join_conference!(name, opts)
        join_params = if join_conference_all_defaults?(opts)
                        name
                      else
                        build_join_conference_params(name, opts)
                      end
        execute_swml(swml_envelope('join_conference', join_params))
      end

      # Validation order + message text mirror the Python reference
      # (core/function_result.py::join_conference). Python renders its
      # valid-value lists via an f-string over a Python list literal, i.e.
      # "one of ['a', 'b']"; we reproduce that exact form.
      def validate_join_conference!(name, opts)
        JOIN_CONFERENCE_ENUMS.each do |opts_key, allowed, message|
          # max_participants is validated immediately after beep, mirroring
          # the Python reference's raise order.
          validate_max_participants!(opts[:max_participants]) if opts_key == :record
          raise ArgumentError, message unless allowed.include?(opts[opts_key])
        end
        raise ArgumentError, 'name cannot be empty' if name.to_s.strip.empty?
      end

      # @api private — the conference participant cap must be a positive Integer no
      # greater than 250, which is the server's own limit.
      #
      # @raise [ArgumentError]
      def validate_max_participants!(max_participants)
        return if max_participants.is_a?(Integer) && max_participants.positive? && max_participants <= 250

        raise ArgumentError, 'max_participants must be a positive integer <= 250'
      end

      # @api private — whether no join_conference option departs from its default,
      # which is what lets the action emit the bare name instead of a params object.
      #
      # @return [Boolean]
      def join_conference_all_defaults?(opts)
        JOIN_CONFERENCE_PARAM_SPEC.none? do |_wire_key, opts_key, include_check|
          include_check.call(opts[opts_key])
        end
      end

      # @api private — the join_conference params object: the name plus only those
      # options that differ from their default, in the spec's declared wire-key order.
      #
      # @return [Hash{String => Object}]
      def build_join_conference_params(name, opts)
        params = { 'name' => name }
        JOIN_CONFERENCE_PARAM_SPEC.each do |wire_key, opts_key, include_check|
          value = opts[opts_key]
          params[wire_key] = value if include_check.call(value)
        end
        params
      end
    end
  end
end
