# frozen_string_literal: true

require 'securerandom'

require_relative 'constants'
require_relative 'device'
require_relative 'collect_config'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Relay — the RELAY realtime (WebSocket / JSON-RPC 2.0) client surface.
  module Relay
    # Represents a live RELAY call.
    #
    # Created by RelayClient on inbound calling.call.receive events or
    # outbound dial responses.
    class Call
      attr_reader :call_id, :node_id, :project_id, :context, :tag,
                  :direction, :device, :segment_id
      attr_accessor :state

      # @param client [Client] the RelayClient this call's RPCs are sent through
      # @param call_id [String] the server's identifier for this call leg
      # @param node_id [String] the RELAY node that owns the call; part of how the
      #   platform addresses it
      # @param project_id [String] the SignalWire project the call belongs to
      # @param context [String] the context the call arrived on (inbound)
      # @param tag [String] the caller-supplied correlation tag, when one was set
      # @param direction [String] `"inbound"` or `"outbound"`
      # @param device [Hash] the raw device descriptor for this leg
      # @param state [String] the call's current state (see {CallState})
      # @param segment_id [String] the call-segment identifier
      def initialize(client, call_id:, node_id:, project_id: '', context: '',
                     tag: '', direction: '', device: {}, state: '', segment_id: '')
        @client = client
        init_identity(call_id, node_id, project_id, context, tag, direction, device, state, segment_id)
        init_event_state
      end

      # Assign the descriptive call attributes (the public attr_readers).
      def init_identity(call_id, node_id, project_id, context, tag, direction, device, state, segment_id)
        @call_id    = call_id
        @node_id    = node_id
        @project_id = project_id
        @context    = context
        @tag        = tag
        @direction  = direction
        @device     = device
        @state      = state
        @segment_id = segment_id
      end

      # Initialize the per-call event/action bookkeeping and synchronization
      # primitives (listeners, active actions, ended-state condition).
      def init_event_state
        # Event listeners: event_type -> list of handlers
        @listeners = {}
        # Active actions indexed by control_id
        @actions   = {}
        # Mutex for thread-safe state access
        @mutex     = Mutex.new
        @ended_cv  = ConditionVariable.new
        @ended     = false
        @end_event = nil
      end

      # ------------------------------------------------------------------
      # Internal RPC primitive
      # ------------------------------------------------------------------

      # Send a calling.<method> JSON-RPC request for this call.
      def _execute(method, extra_params = nil)
        params = {
          'node_id' => node_id,
          'call_id' => call_id
        }
        params.merge!(extra_params) if extra_params
        client.execute("calling.#{method}", params)
      rescue RelayError => e
        # A gone (404/410) call returns {} instead of raising; everything else
        # propagates.
        raise unless call_gone_error?(e)

        warn "[RELAY] Call #{call_id} gone during #{method} (code=#{e.code})"
        {}
      end

      # True when a RelayError carries a 404/410 "call gone" code.
      def call_gone_error?(error)
        code = error.code
        code && [404, 410, '404', '410'].include?(code)
      end

      # ------------------------------------------------------------------
      # Event plumbing
      # ------------------------------------------------------------------

      # Register an event listener for this call.
      #
      # The handler is REQUIRED, matching the reference
      # (``on(self, event_type: str, handler: EventHandler)``). Ruby's block IS
      # the handler; supplying neither registers nothing and raises.
      def on(event_type, handler, &block)
        callback = block || handler
        raise ArgumentError, 'on requires a handler (block or callable)' if callback.nil?

        @mutex.synchronize do
          (@listeners[event_type] ||= []) << callback
        end
      end

      # Called by RelayClient when an event arrives for this call.
      def _dispatch_event(payload)
        event = Relay.parse_event(payload)
        apply_state_event(event) if event.event_type == EVENT_CALL_STATE
        route_to_action(event)
        notify_listeners(event)
      end

      # Update @state from a call.state event and, on ENDED, mark the call
      # ended and resolve any still-pending actions.
      def apply_state_event(event)
        @state = event.params['call_state'] || @state
        return unless @state == CALL_STATE_ENDED

        @mutex.synchronize do
          @ended     = true
          @end_event = event
          @ended_cv.broadcast
        end
        @actions.each_value { |a| a._resolve(event) unless a.done? }
        @actions.clear
      end

      # Route an event to the active action matching its control_id, dropping
      # the action once completed.
      def route_to_action(event)
        control_id = event.params['control_id'] || ''
        return if control_id.empty? || !@actions.key?(control_id)

        action = @actions[control_id]
        action._check_event(event)
        @actions.delete(control_id) if action.completed
      end

      # Fire registered listeners for the event's type, swallowing handler
      # errors so one bad handler can't break dispatch.
      def notify_listeners(event)
        event_type = event.event_type
        handlers = @mutex.synchronize { (@listeners[event_type] || []).dup }
        handlers.each do |handler|
          handler.call(event)
        rescue StandardError => e
          warn "[RELAY] Error in event handler for #{event_type}: #{e.message}"
        end
      end

      # Wait for the call to reach the ended state.
      def wait_for_ended(timeout: nil)
        @mutex.synchronize do
          return @end_event if @ended

          block_until(@ended_cv, @mutex, timeout) { @ended }
          @end_event
        end
      end

      # Block on +condition+ (holding +mutex+) until the block returns truthy,
      # or +timeout+ seconds elapse. Caller must already hold +mutex+.
      def block_until(condition, mutex, timeout)
        if timeout
          deadline = Time.now + timeout
          until yield
            remaining = deadline - Time.now
            break if remaining <= 0

            condition.wait(mutex, remaining)
          end
        else
          condition.wait(mutex) until yield
        end
      end

      # Whether the call has reached its terminal state. Non-blocking, unlike the
      # `wait_for_*` helpers.
      #
      # @return [Boolean]
      def ended?
        @ended
      end

      # Block until the call reaches +target+, returning immediately if the
      # call is already at or past that state. Backs the typed +wait_for_*+
      # helpers below. Mirrors Python's +Call._wait_for_state+: states are
      # ordered created < ringing < answered < ending < ended, and a call
      # already at/past the target resolves with a synthetic state event
      # (matching the legacy SDK's short-circuit).
      def _wait_for_state(target, timeout)
        return synthetic_state_event if state_rank(@state) >= state_rank(target)

        wait_for(
          EVENT_CALL_STATE,
          predicate: ->(e) { e.params['call_state'] == target },
          timeout: timeout
        )
      end

      # Short-circuit event carrying the current @state, used when the call is
      # already at or past the requested wait target.
      def synthetic_state_event
        RelayEvent.new(event_type: EVENT_CALL_STATE, params: { 'call_state' => @state })
      end

      # Ordinal of a call state in CALL_STATES (created < ringing < answered <
      # ending < ended); unknown states rank -1.
      def state_rank(state)
        idx = CALL_STATES.index(state)
        idx.nil? ? -1 : idx
      end

      # Wait until the call is answered (immediate if already answered or past
      # it). Typed wait over #wait_for. Mirrors Python's
      # +Call.wait_for_answered(timeout)+.
      def wait_for_answered(timeout: nil)
        _wait_for_state(CALL_STATE_ANSWERED, timeout)
      end

      # Wait until the call is ringing (immediate if already ringing or past
      # it). Typed wait over #wait_for. Mirrors Python's
      # +Call.wait_for_ringing(timeout)+.
      def wait_for_ringing(timeout: nil)
        _wait_for_state(CALL_STATE_RINGING, timeout)
      end

      # Wait until the call is ending (immediate if already ending or past
      # it). Typed wait over #wait_for. Mirrors Python's
      # +Call.wait_for_ending(timeout)+.
      def wait_for_ending(timeout: nil)
        _wait_for_state(CALL_STATE_ENDING, timeout)
      end

      # Wait for a specific event, optionally filtered by a predicate.
      #
      # Registers a one-shot listener for +event_type+ and blocks until the
      # first matching event arrives (or +timeout+ seconds elapse). When
      # +predicate+ is supplied, only events for which it returns truthy
      # satisfy the wait. Blocks the calling thread on a ConditionVariable,
      # mirroring +#wait_for_ended+'s synchronization model.
      #
      # @param event_type [String] the RELAY event type to wait for
      # @param predicate [#call, nil] optional filter +->(event) { ... }+
      # @param timeout [Numeric, nil] optional timeout in seconds
      # @return [RelayEvent, nil] the matching event, or +nil+ on timeout
      def wait_for(event_type, predicate: nil, timeout: nil)
        mutex   = Mutex.new
        cv      = ConditionVariable.new
        state   = { result: nil, satisfied: false }
        handler = one_shot_handler(mutex, cv, state, predicate)

        on(event_type, handler)
        with_one_shot_listener(event_type, handler) do
          mutex.synchronize { block_until(cv, mutex, timeout) { state[:satisfied] } }
          state[:result]
        end
      end

      # Run the block, guaranteeing the one-shot listener is removed afterward.
      def with_one_shot_listener(event_type, handler)
        yield
      ensure
        remove_listener(event_type, handler)
      end

      # Build a one-shot event handler that, under +mutex+, records the first
      # event satisfying +predicate+ into +state+ and signals +cv+.
      def one_shot_handler(mutex, condition, state, predicate)
        lambda do |event|
          mutex.synchronize do
            next if state[:satisfied]
            next unless predicate.nil? || predicate.call(event)

            state[:result]    = event
            state[:satisfied] = true
            condition.broadcast
          end
        end
      end

      # Remove a one-shot listener so it doesn't fire for later events.
      def remove_listener(event_type, handler)
        @mutex.synchronize do
          listeners = @listeners[event_type]
          listeners&.delete(handler)
        end
      end

      # ------------------------------------------------------------------
      # Action helper
      # ------------------------------------------------------------------

      def start_action(action, method, params, on_completed: nil)
        if @state == CALL_STATE_ENDED
          warn "[RELAY] Call #{call_id} already ended, skipping #{method}"
          action._resolve(gone_event)
          return action
        end
        action._set_on_completed(on_completed) if on_completed
        @actions[action.control_id] = action
        result = execute_action(action, method, params)
        # _execute returns {} when the call is gone (404/410)
        resolve_gone(action) if result.nil? || result.empty?
        action
      end

      # Run the action's RPC; on error drop it, resolve it gone, and re-raise.
      def execute_action(action, method, params)
        _execute(method, params)
      rescue StandardError
        @actions.delete(action.control_id)
        action._resolve(gone_event)
        raise
      end

      # Drop a pending action and resolve it with a synthetic gone event.
      def resolve_gone(action)
        @actions.delete(action.control_id)
        action._resolve(gone_event) unless action.done?
      end

      # Synthetic "call gone" terminal event.
      def gone_event
        RelayEvent.new(event_type: '', params: {})
      end

      # ------------------------------------------------------------------
      # Call lifecycle methods
      # ------------------------------------------------------------------

      def answer(**kwargs)
        _execute('answer', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

      # End the call by sending the RELAY `calling.end` method.
      #
      # @param reason [String] why the call is ending, sent as the `reason` wire param
      # @return [Hash] the server's result
      def hangup(reason: 'hangup')
        _execute('end', { 'reason' => reason })
      end

      # Hand the call back to the platform's dial plan without answering it, so
      # another consumer (or the next route) can take it. Sends `calling.pass`.
      #
      # @return [Hash] the server's result
      def pass_call
        _execute('pass')
      end

      # ------------------------------------------------------------------
      # Connect
      # ------------------------------------------------------------------

      def connect(devices:, **kwargs)
        params = { 'devices' => devices }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('connect', params)
      end

      # Tear down a peer connection established by {#connect}, leaving this leg up.
      # Sends `calling.disconnect`.
      #
      # @return [Hash] the server's result
      def disconnect
        _execute('disconnect')
      end

      # ------------------------------------------------------------------
      # Hold / Unhold
      # ------------------------------------------------------------------

      def hold
        _execute('hold')
      end

      # Take the call off hold, resuming two-way media. Sends `calling.unhold`.
      #
      # @return [Hash] the server's result
      def unhold
        _execute('unhold')
      end

      # ------------------------------------------------------------------
      # Denoise
      # ------------------------------------------------------------------

      def denoise
        _execute('denoise')
      end

      # Stop background-noise reduction on the call. Sends `calling.denoise.stop`.
      #
      # @return [Hash] the server's result
      def denoise_stop
        _execute('denoise.stop')
      end

      # ------------------------------------------------------------------
      # Transfer
      # ------------------------------------------------------------------

      def transfer(dest:, **kwargs)
        params = { 'dest' => dest }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('transfer', params)
      end

      # ------------------------------------------------------------------
      # Conference
      # ------------------------------------------------------------------

      def join_conference(name:, **kwargs)
        params = { 'name' => name }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('join_conference', params)
      end

      # Remove this call from a conference it joined. Sends
      # `calling.leave_conference`.
      #
      # @param conference_id [String] the conference to leave
      # @return [Hash] the server's result
      def leave_conference(conference_id:)
        _execute('leave_conference', { 'conference_id' => conference_id })
      end

      # ------------------------------------------------------------------
      # Echo
      # ------------------------------------------------------------------

      def echo(**kwargs)
        _execute('echo', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

      # ------------------------------------------------------------------
      # Digit binding
      # ------------------------------------------------------------------

      def bind_digit(digits:, bind_method:, **kwargs)
        params = { 'digits' => digits, 'bind_method' => bind_method }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('bind_digit', params)
      end

      # Remove every DTMF binding registered via {#bind_digit}, so digits stop
      # triggering their bound behaviour. Sends `calling.clear_digit_bindings`.
      #
      # @param kwargs [Hash] extra wire params, keys stringified; omitted when empty
      # @return [Hash] the server's result
      def clear_digit_bindings(**kwargs)
        _execute('clear_digit_bindings', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

      # ------------------------------------------------------------------
      # Queue
      # ------------------------------------------------------------------

      def queue_enter(queue_name:, control_id: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'queue_name' => queue_name }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('queue.enter', params)
      end

      # Remove the call from a queue it entered. Sends `calling.queue.leave`.
      #
      # @param queue_name [String] the queue to leave
      # @param control_id [String, nil] correlation id; a fresh UUID is minted when omitted
      # @param kwargs [Hash] extra wire params, keys stringified
      # @return [Hash] the server's result
      def queue_leave(queue_name:, control_id: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'queue_name' => queue_name }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('queue.leave', params)
      end

      # ------------------------------------------------------------------
      # Refer (SIP REFER)
      # ------------------------------------------------------------------

      def refer(device:, **kwargs)
        params = { 'device' => device }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('refer', params)
      end

      # ------------------------------------------------------------------
      # Send digits
      # ------------------------------------------------------------------

      def send_digits(digits:, control_id: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'digits' => digits }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('send_digits', params)
      end

      # ------------------------------------------------------------------
      # Live transcribe / translate
      # ------------------------------------------------------------------

      def live_transcribe(action:, **kwargs)
        params = { 'action' => action }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('live_transcribe', params)
      end

      # Start, stop or reconfigure real-time translation on the call. Sends
      # `calling.live_translate`.
      #
      # @param action [String] the operation to perform, sent as the `action` wire param
      # @param kwargs [Hash] the translation configuration, keys stringified
      # @return [Hash] the server's result
      def live_translate(action:, **kwargs)
        params = { 'action' => action }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('live_translate', params)
      end

      # ------------------------------------------------------------------
      # Room
      # ------------------------------------------------------------------

      def join_room(name:, **kwargs)
        params = { 'name' => name }
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('join_room', params)
      end

      # Remove this call from a video room it joined. Sends `calling.leave_room`.
      #
      # @return [Hash] the server's result
      def leave_room
        _execute('leave_room')
      end

      # ------------------------------------------------------------------
      # User events
      # ------------------------------------------------------------------

      def user_event(event: nil, **kwargs)
        params = {}
        params['event'] = event if event
        kwargs.each { |k, v| params[k.to_s] = v }
        _execute('user_event', params.empty? ? nil : params)
      end

      # ------------------------------------------------------------------
      # AI
      # ------------------------------------------------------------------

      def ai_message(**kwargs)
        _execute('ai_message', kwargs.transform_keys(&:to_s))
      end

      # Put the AI agent attached to this call on hold, so it stops responding while
      # the leg stays up. Sends `calling.ai_hold`.
      #
      # @param kwargs [Hash] extra wire params, keys stringified; omitted when empty
      # @return [Hash] the server's result
      def ai_hold(**kwargs)
        _execute('ai_hold', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

      # Resume an AI agent that was held by {#ai_hold}. Sends `calling.ai_unhold`.
      #
      # @param kwargs [Hash] extra wire params, keys stringified; omitted when empty
      # @return [Hash] the server's result
      def ai_unhold(**kwargs)
        _execute('ai_unhold', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

      # Attach an Amazon Bedrock AI agent to the call. This is its own RELAY method
      # (`calling.amazon_bedrock`), not `calling.ai` with an engine parameter.
      #
      # @param kwargs [Hash] the Bedrock agent configuration, keys stringified
      # @return [Hash] the server's result
      def amazon_bedrock(**kwargs)
        _execute('amazon_bedrock', kwargs.transform_keys(&:to_s))
      end

      # ------------------------------------------------------------------
      # Audio playback (returns PlayAction)
      # ------------------------------------------------------------------

      def play(media, volume: nil, direction: nil, loop_count: nil,
               control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'play' => media }
        params['volume']    = volume if volume
        params['direction'] = direction if direction
        params['loop']      = loop_count if loop_count
        kwargs.each { |k, v| params[k.to_s] = v }
        action = PlayAction.new(self, cid)
        start_action(action, 'play', params, on_completed: on_completed)
      end

      # Play text-to-speech. Typed convenience over #play.
      #
      # Restores the legacy +call.play_tts(text)+ ergonomics so callers don't
      # hand-build the +{ 'type' => 'tts', 'params' => {...} }+ media shape.
      # Mirrors Python's +Call.play_tts(text, *, language, gender, voice,
      # volume, on_completed)+.
      #
      # Wire shape: play [{ 'type' => 'tts', 'params' => { 'text', language?,
      # gender?, voice? } }] with an optional top-level +volume+.
      def play_tts(text, language: nil, gender: nil, voice: nil, volume: nil,
                   on_completed: nil)
        tts = { 'text' => text }
        tts['language'] = language if language
        tts['gender']   = gender if gender
        tts['voice']    = voice if voice
        play([{ 'type' => 'tts', 'params' => tts }],
             volume: volume, on_completed: on_completed)
      end

      # Play an audio file from a URL. Typed convenience over #play.
      # Mirrors Python's +Call.play_audio(url, *, volume, on_completed)+.
      #
      # Wire shape: play [{ 'type' => 'audio', 'params' => { 'url' } }] with an
      # optional top-level +volume+.
      def play_audio(url, volume: nil, on_completed: nil)
        play([{ 'type' => 'audio', 'params' => { 'url' => url } }],
             volume: volume, on_completed: on_completed)
      end

      # Play silence for +duration+ seconds. Typed convenience over #play.
      # Mirrors Python's +Call.play_silence(duration, *, on_completed)+.
      #
      # Wire shape: play [{ 'type' => 'silence', 'params' => { 'duration' } }].
      def play_silence(duration, on_completed: nil)
        play([{ 'type' => 'silence', 'params' => { 'duration' => duration } }],
             on_completed: on_completed)
      end

      # Play a named ringtone by country code. Typed convenience over #play.
      # Mirrors Python's +Call.play_ringtone(name, *, duration, volume,
      # on_completed)+.
      #
      # Wire shape: play [{ 'type' => 'ringtone', 'params' => { 'name',
      # duration? } }] with an optional top-level +volume+.
      def play_ringtone(name, duration: nil, volume: nil, on_completed: nil)
        ringtone = { 'name' => name }
        ringtone['duration'] = duration if duration
        play([{ 'type' => 'ringtone', 'params' => ringtone }],
             volume: volume, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Recording (returns RecordAction)
      # ------------------------------------------------------------------

      def record(audio: nil, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        record_obj = { 'audio' => audio || {} }
        params = { 'control_id' => cid, 'record' => record_obj }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = RecordAction.new(self, cid)
        start_action(action, 'record', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Input collection
      # ------------------------------------------------------------------

      def play_and_collect(media, collect, volume: nil, control_id: nil,
                           on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'play' => media, 'collect' => collect }
        params['volume'] = volume if volume
        kwargs.each { |k, v| params[k.to_s] = v }
        action = CollectAction.new(self, cid)
        start_action(action, 'play_and_collect', params, on_completed: on_completed)
      end

      # Collect caller input WITHOUT playing a prompt first, for when the prompt was
      # played separately. Sends `calling.collect` and returns immediately.
      #
      # @param collect_opts [Hash] the collect configuration (digits / speech rules),
      #   merged into the wire params with its keys stringified
      # @param control_id [String, nil] correlation id; a fresh UUID is minted when omitted
      # @param on_completed [Proc, nil] invoked with the terminal event when the collect finishes
      # @param kwargs [Hash] extra wire params, keys stringified
      # @return [StandaloneCollectAction] a handle to wait on or stop
      def collect(collect_opts, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        params.merge!(collect_opts.transform_keys(&:to_s)) if collect_opts.is_a?(Hash)
        kwargs.each { |k, v| params[k.to_s] = v }
        action = StandaloneCollectAction.new(self, cid)
        start_action(action, 'collect', params, on_completed: on_completed)
      end

      # Play TTS then collect input. Typed media over #play_and_collect.
      # Mirrors Python's +Call.prompt_tts(text, collect, *, language, gender,
      # voice, volume, on_completed)+.
      #
      # Wire shape: play_and_collect [{ 'type' => 'tts', 'params' => { 'text',
      # language?, gender?, voice? } }] with the given +collect+ object and an
      # optional top-level +volume+.
      def prompt_tts(text, collect, language: nil, gender: nil, voice: nil,
                     volume: nil, on_completed: nil)
        tts = { 'text' => text }
        tts['language'] = language if language
        tts['gender']   = gender if gender
        tts['voice']    = voice if voice
        play_and_collect([{ 'type' => 'tts', 'params' => tts }], collect,
                         volume: volume, on_completed: on_completed)
      end

      # Play an audio file then collect input. Typed media over
      # #play_and_collect. Mirrors Python's +Call.prompt_audio(url, collect,
      # *, volume, on_completed)+.
      #
      # Wire shape: play_and_collect [{ 'type' => 'audio', 'params' =>
      # { 'url' } }] with the given +collect+ object and an optional top-level
      # +volume+.
      def prompt_audio(url, collect, volume: nil, on_completed: nil)
        play_and_collect([{ 'type' => 'audio', 'params' => { 'url' => url } }],
                         collect, volume: volume, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Detect
      # ------------------------------------------------------------------

      def detect(detect_opts, timeout: nil, control_id: nil,
                 on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'detect' => detect_opts }
        params['timeout'] = timeout if timeout
        kwargs.each { |k, v| params[k.to_s] = v }
        action = DetectAction.new(self, cid)
        start_action(action, 'detect', params, on_completed: on_completed)
      end

      # Detect DTMF digits. Typed convenience over #detect.
      # Mirrors Python's +Call.detect_digit(*, digits, timeout,
      # on_completed)+.
      #
      # Wire shape: detect { 'type' => 'digit', 'params' => { digits? } } with
      # an optional top-level +timeout+.
      def detect_digit(digits: nil, timeout: nil, on_completed: nil)
        params = {}
        params['digits'] = digits if digits
        detect({ 'type' => 'digit', 'params' => params },
               timeout: timeout, on_completed: on_completed)
      end

      # Detect human vs answering machine (AMD). Typed convenience over
      # #detect. Mirrors Python's +Call.detect_answering_machine(*,
      # initial_timeout, end_silence_timeout, machine_voice_threshold,
      # machine_words_threshold, detect_interruptions, detect_message_end,
      # timeout, on_completed)+.
      #
      # Wire shape: detect { 'type' => 'machine', 'params' => { ...only the
      # provided fields... } } with an optional top-level +timeout+.
      def detect_answering_machine(initial_timeout: nil, end_silence_timeout: nil,
                                   machine_voice_threshold: nil,
                                   machine_words_threshold: nil,
                                   detect_interruptions: nil,
                                   detect_message_end: nil,
                                   timeout: nil, on_completed: nil)
        params = {}
        params['initial_timeout']         = initial_timeout unless initial_timeout.nil?
        params['end_silence_timeout']     = end_silence_timeout unless end_silence_timeout.nil?
        params['machine_voice_threshold'] = machine_voice_threshold unless machine_voice_threshold.nil?
        params['machine_words_threshold'] = machine_words_threshold unless machine_words_threshold.nil?
        params['detect_interruptions']    = detect_interruptions unless detect_interruptions.nil?
        params['detect_message_end']      = detect_message_end unless detect_message_end.nil?
        detect({ 'type' => 'machine', 'params' => params },
               timeout: timeout, on_completed: on_completed)
      end

      # Detect a fax tone (CED/CNG). Typed convenience over #detect.
      # Mirrors Python's +Call.detect_fax(*, tone, timeout, on_completed)+.
      #
      # Wire shape: detect { 'type' => 'fax', 'params' => { tone? } } with an
      # optional top-level +timeout+.
      def detect_fax(tone: nil, timeout: nil, on_completed: nil)
        params = {}
        params['tone'] = tone if tone
        detect({ 'type' => 'fax', 'params' => params },
               timeout: timeout, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Fax
      # ------------------------------------------------------------------

      def send_fax(document:, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'document' => document }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = FaxAction.new(self, cid, 'send_fax')
        start_action(action, 'send_fax', params, on_completed: on_completed)
      end

      # Start receiving an inbound fax on this call. Sends `calling.receive_fax` and
      # returns immediately.
      #
      # @param control_id [String, nil] correlation id; a fresh UUID is minted when omitted
      # @param on_completed [Proc, nil] invoked with the terminal event when the fax finishes
      # @param kwargs [Hash] extra wire params, keys stringified
      # @return [FaxAction] a handle to wait on or stop
      def receive_fax(control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = FaxAction.new(self, cid, 'receive_fax')
        start_action(action, 'receive_fax', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Tap
      # ------------------------------------------------------------------

      def tap_audio(tap_opts, device:, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'tap' => tap_opts, 'device' => device }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = TapAction.new(self, cid)
        start_action(action, 'tap', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Stream
      # ------------------------------------------------------------------

      def stream(url:, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'url' => url }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = StreamAction.new(self, cid)
        start_action(action, 'stream', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Transcribe
      # ------------------------------------------------------------------

      def transcribe(control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = TranscribeAction.new(self, cid)
        start_action(action, 'transcribe', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Pay
      # ------------------------------------------------------------------

      def pay(payment_connector_url:, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'payment_connector_url' => payment_connector_url }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = PayAction.new(self, cid)
        start_action(action, 'pay', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # AI (returns AIAction)
      # ------------------------------------------------------------------

      def ai(control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = AIAction.new(self, cid)
        start_action(action, 'ai', params, on_completed: on_completed)
      end

      # A short human-readable summary: the call id, its current state and its
      # direction. Carries no credentials.
      #
      # @return [String]
      def to_s
        "Call(id=#{call_id}, state=#{@state}, direction=#{direction})"
      end

      # Same as {#to_s} — the default `#inspect` would dump every ivar including the
      # owning client.
      #
      # @return [String]
      def inspect
        to_s
      end

      # Owning RelayClient — set once at construction, read-only thereafter.
      attr_reader :client

      # Internal helpers (formerly leading-underscore by convention). Not part of
      # the public/Python surface — declared private so the cross-port surface
      # enumerator continues to exclude them. _execute / _dispatch_event /
      # _wait_for_state stay public+underscored: they are invoked cross-instance
      # (Action, RelayClient, and the test suite call them with an explicit
      # receiver), which private/protected would break.
      private :client, :init_identity, :init_event_state, :call_gone_error?,
              :apply_state_event, :route_to_action, :notify_listeners, :block_until,
              :synthetic_state_event, :state_rank, :with_one_shot_listener,
              :one_shot_handler, :remove_listener, :start_action, :execute_action,
              :resolve_gone, :gone_event
    end
  end
end
