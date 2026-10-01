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
    # bare string or the named constant interchangeably — they are literally
    # the same object. The +FunctionResult+ validators below reference
    # these +ALL+ arrays directly, so the named set and the validated set
    # can never drift apart (single source of truth).
    #
    # Idiom note: these follow +SignalWire::Relay+'s constants module
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
    # Kept DISTINCT from {TapDirection} even though both verbs name the channels
    # speak/listen/both: each verb is validated against its OWN list.
    module RecordDirection
      SPEAK  = 'speak'
      LISTEN = 'listen'
      BOTH   = 'both'

      # Every valid +record_call+ direction, in wire order.
      ALL = [SPEAK, LISTEN, BOTH].freeze
    end

    # Channel selection for the +tap+ verb: +speak+ (what the party says),
    # +listen+ (what the party hears), +both+. The SWML tap verb's enum is
    # speak/listen/both (schema.json $defs/Tap); +hear+ is not a tap direction
    # and produced SWML the platform rejects. Distinct from the RELAY
    # play/record/tap direction vocabulary.
    module TapDirection
      SPEAK  = 'speak'
      LISTEN = 'listen'
      BOTH   = 'both'

      # Every valid +tap+ direction, in wire order.
      ALL = [SPEAK, LISTEN, BOTH].freeze
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
      # within length limits; the value is wire-load-bearing).
      PAY_DEFAULT_AI_RESPONSE =
        'The payment status is ${pay_result}, do not mention anything else ' \
        'about collecting payment if successful.'

      # Enum validations for +join_conference+, in the order they are checked:
      # the FIRST invalid value in this order is the one that raises.
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

      # A SWML variable reference (+${...}+ / +%{...}+), passed through as written
      # where a verb takes an integer.
      SWML_VAR = /\A[$%]\{.*\}\z/m

      # Spec for the non-default conference params, in exact wire-key order.
      # Each entry: [wire_key, opts_key, ->(value) { include? }]. Driving the
      # build off this table pins the emitted key insertion order while staying
      # flat (one loop, not 18 branches).
      JOIN_CONFERENCE_PARAM_SPEC = [
        ['muted',            :muted,            ->(v) { v }],
        ['beep',             :beep,             ->(v) { v != 'true' }],
        ['start_on_enter',   :start_on_enter,   :!.to_proc],
        ['end_on_exit',      :end_on_exit,      ->(v) { v }],
        ['wait_url',         :wait_url,         ->(v) { v }],
        ['max_participants', :max_participants, ->(v) { !v.nil? }],
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

      # @param response [String, Hash, nil] text the AI speaks back to the user
      #   (or the structured {tool_result, tool_prompt} form)
      # @param post_process [Boolean] whether to let AI take another turn before executing actions
      # @param tool_result [String, nil] structured-response outcome (see {#set_tool_response})
      # @param tool_prompt [String, nil] structured-response instruction (see {#set_tool_response})
      def initialize(response = nil, post_process: false, tool_result: nil, tool_prompt: nil)
        @response = response || ''
        @action = []
        @post_process = post_process
        return if tool_result.nil? && tool_prompt.nil?

        set_tool_response(tool_result: tool_result,
                          tool_prompt: tool_prompt)
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

      # Set the structured response form, separating outcome from instruction.
      #
      # +response+ may be a plain string, or an object with two distinct fields:
      #
      #   { 'tool_result' => 'status: on hold',
      #     'tool_prompt' => 'Tell the caller you are placing them on hold.' }
      #
      # - +tool_result+: what the tool DID — a factual status line for the model
      #   to reason from ("hold initiated", "payment declined", "3 seats left").
      # - +tool_prompt+: what the model should now SAY — an instruction, second
      #   person, exactly like the string form of +response+.
      #
      # Splitting them keeps the model from reading a status line aloud, and keeps
      # the spoken instruction from being mistaken for data.
      #
      # @param tool_result [String, nil] factual outcome of the call; omit if there
      #   is nothing to report beyond the instruction
      # @param tool_prompt [String, nil] instruction for what to say next; omit for
      #   a silent status-only result
      # @return [self]
      def set_tool_response(tool_result: nil, tool_prompt: nil)
        payload = {}
        payload['tool_result'] = tool_result unless tool_result.nil?
        payload['tool_prompt'] = tool_prompt unless tool_prompt.nil?
        @response = payload
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

      # Put the call on hold, optionally announcing it and routing what happens next.
      #
      # The SWML hold action carries no prompt of its own, and during hold speech
      # detection is paused, so anything the caller needs to hear has to be said
      # BEFORE the action lands. Passing +prompt+ wires that up: it becomes the
      # result's response (a prompt into the model's context, not speech) and
      # switches on post_process, so the model takes one more turn and speaks
      # before the hold executes:
      #
      #   FunctionResult.new.hold('Tell the caller you are placing them on hold.', 120)
      #
      # +step+ and +timeout_step+ land the caller in a chosen step when the hold
      # ends (deferred: the transition fires when the hold actually ends). Omitting
      # both emits the bare integer form and the caller resumes where they were.
      #
      # @param prompt [String, Integer, nil] instruction for the model to deliver
      #   before the hold takes effect (sets the response and post_process). An
      #   Integer here is treated as +timeout+, so +hold(120)+ keeps working.
      # @param timeout [Integer] seconds, clamped to 0..900 (default 300)
      # @param step [String, nil] step to move to when the call is taken off hold
      # @param timeout_step [String, nil] step to move to when the hold times out
      # @return [self]
      def hold(prompt = nil, timeout = 300, step: nil, timeout_step: nil)
        # Back-compat: hold(120) means hold(timeout: 120). A boolean is neither a
        # prompt nor a timeout, so it is dropped.
        timeout = prompt if prompt.is_a?(Integer)
        prompt = nil unless prompt.is_a?(String)
        unless prompt.nil?
          set_tool_response(tool_result: 'status: on hold', tool_prompt: prompt)
          @post_process = true
        end
        add_action('hold', hold_value(timeout.clamp(0, 900), step, timeout_step))
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

      # Change the agent's voice for the rest of the call.
      #
      # The voice is an +engine.voice:model+ spec, the same form a language's
      # voice takes in the SWML +languages+ list (for example "elevenlabs.rachel");
      # the +engine.+ prefix and the +:model+ suffix are optional. It replaces the
      # voice of the language currently in use. The platform applies it at the next
      # speech batch boundary, never mid-utterance, and it then persists for that
      # language for the rest of the call. An empty spec is ignored.
      #
      # @param voice [String] voice spec in +engine.voice:model+ form
      # @return [self]
      def change_voice(voice)
        add_action('change_voice', voice)
      end

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
        # transfer rides BESIDE the SWML document, not inside it — the same shape
        # connect() and swml_transfer() emit. Inside the document it is not a SWML
        # key and the call never exits the agent.
        action = { 'SWML' => coerce_swml_content(swml_content) }
        action['transfer'] = 'true' if transfer
        @action << action
        self
      end

      # Join an ad-hoc audio conference via SWML.
      #
      # @param name [String] conference name (required)
      # @return [self]
      def join_conference(name, muted: false, beep: 'true',
                          start_on_enter: true, end_on_exit: false,
                          wait_url: nil, max_participants: nil,
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
      # @param direction [String] "speak", "listen", or "both"
      # @param codec [String] "PCMU" or "PCMA"
      # @param rtp_ptime [Integer] packetization time in ms
      # @param status_url [String, nil]
      # @return [self]
      def tap(uri, control_id: nil, direction: TapDirection::BOTH, codec: Codec::PCMU,
              rtp_ptime: 20, status_url: nil)
        validate_tap!(direction, codec, rtp_ptime)

        tap_params = { 'uri' => uri }
        tap_params['control_id'] = control_id if control_id
        # Always sent: the verb's own default is "speak", not this helper's "both",
        # so omitting it would tap less than the caller asked for.
        tap_params['direction']  = direction
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

      # Send a message and/or global_data to an AI agent on another call.
      #
      # Two payloads, either or both:
      # - +message_text+ lands as a turn in the other agent's conversation, so it
      #   competes for attention with everything else arriving that moment.
      # - +global_data+ is MERGED into the other call's global_data, where it is
      #   silent until something expands it — the better channel for content a
      #   later prompt needs to speak (write +${global_data.your_key}+ into the
      #   step that will run).
      #
      # @param call_id [String] the call ID of the target call
      # @param message_text [String, nil] optional message to inject
      # @param role [String] role for the message (default "system")
      # @param global_data [Hash, nil] optional object merged into the target
      #   call's global_data
      # @return [self]
      # @raise [ArgumentError] when neither message_text nor global_data is given
      def rpc_ai_message(call_id, message_text = nil, role: 'system', global_data: nil)
        params = {}
        unless message_text.nil?
          params['role'] = role
          params['message_text'] = message_text
        end
        params['global_data'] = global_data unless global_data.nil?
        raise ArgumentError, 'rpc_ai_message needs message_text, global_data, or both' if params.empty?

        execute_rpc('ai_message', call_id: call_id, params: params)
      end

      # Merge data into another call's global_data, with no conversation turn.
      # A thin wrapper over +rpc_ai_message(global_data:)+ — use it when the other
      # call needs a value rather than an instruction; the destination prompt reads
      # it back with +${global_data.key}+.
      #
      # @param call_id [String] the call ID of the target call
      # @param data [Hash] object merged into that call's global_data
      # @return [self]
      def rpc_ai_global_data(call_id, data)
        rpc_ai_message(call_id, global_data: data)
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

      # @api private — reject a tap whose direction is not speak/listen/both, whose
      # codec is not PCMU/PCMA, or whose packetization time is not positive.
      #
      # @raise [ArgumentError] naming the offending field
      def validate_tap!(direction, codec, rtp_ptime)
        unless TapDirection::ALL.include?(direction)
          raise ArgumentError, "direction must be 'speak', 'listen', or 'both'"
        end
        raise ArgumentError, "codec must be 'PCMU' or 'PCMA'" unless Codec::ALL.include?(codec)
        raise ArgumentError, 'rtp_ptime must be positive' unless rtp_ptime.positive?
      end

      # Assign each truthy value into +target+ under its wire key, in the
      # given hash's insertion order (preserving wire key order).
      def assign_present(target, pairs)
        pairs.each { |key, value| target[key] = value if value }
        target
      end

      # Build the object-form +context_switch+ payload. Key order is
      # wire-load-bearing: system_prompt, user_prompt, consolidate,
      # full_reset, isolated.
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
      # postal_code, then the optional tail) is wire-load-bearing.
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
      # wire-load-bearing.
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

      # The blank test +send_sms+ applies to its arguments: nil, or responds to
      # #empty? and is empty. (An empty String is truthy in Ruby, so a plain
      # truthiness check would not do.)
      def sms_blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      # @api private — the join_conference action. When every option is at its
      # default the wire value collapses to the bare conference NAME rather than a
      # params object.
      def join_conference_action(name, opts)
        validate_join_conference!(name, opts)
        join_params = if join_conference_all_defaults?(opts)
                        name
                      else
                        build_join_conference_params(name, opts)
                      end
        execute_swml(swml_envelope('join_conference', join_params))
      end

      # Validation order and message text are both load-bearing. Each
      # valid-value list renders bracketed with single-quoted, comma-separated
      # members — "one of ['a', 'b']" — so the message a caller sees is stable.
      def validate_join_conference!(name, opts)
        JOIN_CONFERENCE_ENUMS.each do |opts_key, allowed, message|
          # max_participants is validated immediately after beep, before
          # record — the order decides which error a caller sees first.
          normalize_max_participants!(opts) if opts_key == :record
          raise ArgumentError, message unless allowed.include?(opts[opts_key])
        end
        raise ArgumentError, 'name cannot be empty' if name.to_s.strip.empty?
      end

      # @api private — validate + coerce the optional conference participant cap in
      # place: at least 2 (the platform's conference refuses fewer), no upper limit.
      def normalize_max_participants!(opts)
        return if opts[:max_participants].nil?

        opts[:max_participants] = swml_int('max_participants', opts[:max_participants], minimum: 2)
      end

      # @api private — +value+ as an Integer for a SWML verb, or ArgumentError.
      # Accepts an Integer, an integral Float, a string of ASCII digits, or a SWML
      # variable reference (passed through as written). An Integer must be within
      # +minimum+ / +maximum+ when they are given. The conference participant cap
      # is at least 2 (the platform's conference refuses fewer) with no upper limit.
      #
      # @raise [ArgumentError]
      def swml_int(name, value, minimum: nil, maximum: nil)
        number = swml_int_number(value)
        return number if number.is_a?(String)
        return number if !number.nil? && (minimum.nil? || number >= minimum) && (maximum.nil? || number <= maximum)

        raise ArgumentError, "#{name} must be #{swml_int_expected(minimum, maximum)}, got #{value.inspect}"
      end

      # @api private — the Integer a SWML int argument denotes, the SWML variable
      # string itself, or nil when it denotes neither.
      def swml_int_number(value)
        case value
        when String then swml_int_string(value.strip)
        when Integer then value
        when Float then value.finite? && value == value.floor ? value.to_i : nil
        end
      end

      # @api private — a SWML int given as a string: the variable reference itself,
      # the Integer a string of ASCII digits denotes, or nil.
      def swml_int_string(text)
        return text if SWML_VAR.match?(text)

        text.match?(/\A-?[0-9]+\z/) ? Integer(text, 10) : nil
      end

      # @api private — the "expected" half of a swml_int error message.
      def swml_int_expected(minimum, maximum)
        if minimum && maximum then "an integer from #{minimum} to #{maximum}"
        elsif minimum then "an integer of at least #{minimum}"
        elsif maximum then "an integer of at most #{maximum}"
        else 'an integer'
        end
      end

      # @api private — the hold action value: the bare clamped timeout unless a
      # step is routed, so existing output is unchanged.
      def hold_value(timeout, step, timeout_step)
        return timeout if step.nil? && timeout_step.nil?

        config = { 'timeout' => timeout }
        config['step'] = step unless step.nil?
        config['timeout_step'] = timeout_step unless timeout_step.nil?
        config
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
