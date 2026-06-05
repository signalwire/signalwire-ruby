# frozen_string_literal: true

require 'securerandom'

require_relative 'constants'
require_relative 'device'
require_relative 'collect_config'

module SignalWire
  module Relay
    # Represents a live RELAY call.
    #
    # Created by RelayClient on inbound calling.call.receive events or
    # outbound dial responses.
    class Call
      attr_reader :call_id, :node_id, :project_id, :context, :tag,
                  :direction, :device, :segment_id
      attr_accessor :state

      def initialize(client, call_id:, node_id:, project_id: '', context: '',
                     tag: '', direction: '', device: {}, state: '', segment_id: '')
        @client     = client
        @call_id    = call_id
        @node_id    = node_id
        @project_id = project_id
        @context    = context
        @tag        = tag
        @direction  = direction
        @device     = device
        @state      = state
        @segment_id = segment_id

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
        rpc_method = "calling.#{method}"
        params = {
          'node_id' => @node_id,
          'call_id' => @call_id
        }
        params.merge!(extra_params) if extra_params
        begin
          @client.execute(rpc_method, params)
        rescue RelayError => e
          code = e.code
          if code && [404, 410, '404', '410'].include?(code)
            $stderr.puts "[RELAY] Call #{@call_id} gone during #{method} (code=#{code})"
            return {}
          end
          raise
        end
      end

      # ------------------------------------------------------------------
      # Event plumbing
      # ------------------------------------------------------------------

      # Register an event listener for this call.
      def on(event_type, &handler)
        @mutex.synchronize do
          (@listeners[event_type] ||= []) << handler
        end
      end

      # Called by RelayClient when an event arrives for this call.
      def _dispatch_event(payload)
        event = Relay.parse_event(payload)
        event_type = event.event_type

        # Update call state
        if event_type == EVENT_CALL_STATE
          @state = event.params['call_state'] || @state
          if @state == CALL_STATE_ENDED
            @mutex.synchronize do
              @ended     = true
              @end_event = event
              @ended_cv.broadcast
            end
            # Resolve any pending actions
            @actions.each_value { |a| a._resolve(event) unless a.done? }
            @actions.clear
          end
        end

        # Route to active actions by control_id
        control_id = event.params['control_id'] || ''
        if !control_id.empty? && @actions.key?(control_id)
          action = @actions[control_id]
          action._check_event(event)
          @actions.delete(control_id) if action.completed
        end

        # Notify registered listeners
        handlers = @mutex.synchronize { (@listeners[event_type] || []).dup }
        handlers.each do |handler|
          begin
            handler.call(event)
          rescue => e
            $stderr.puts "[RELAY] Error in event handler for #{event_type}: #{e.message}"
          end
        end
      end

      # Wait for the call to reach the ended state.
      def wait_for_ended(timeout: nil)
        @mutex.synchronize do
          return @end_event if @ended

          if timeout
            deadline = Time.now + timeout
            while !@ended
              remaining = deadline - Time.now
              break if remaining <= 0
              @ended_cv.wait(@mutex, remaining)
            end
          else
            @ended_cv.wait(@mutex) until @ended
          end
          @end_event
        end
      end

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
        order = CALL_STATES

        rank = lambda do |s|
          idx = order.index(s)
          idx.nil? ? -1 : idx
        end

        if rank.call(@state) >= rank.call(target)
          return RelayEvent.new(
            event_type: EVENT_CALL_STATE,
            params:     { 'call_state' => @state }
          )
        end

        wait_for(
          EVENT_CALL_STATE,
          predicate: ->(e) { e.params['call_state'] == target },
          timeout:   timeout
        )
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
      # Python parity: ``Call.wait_for(event_type, predicate=None,
      # timeout=None)``. Registers a one-shot listener for +event_type+ and
      # blocks until the first matching event arrives (or +timeout+ seconds
      # elapse). When +predicate+ is supplied, only events for which it
      # returns truthy satisfy the wait. The Python coroutine resolves an
      # asyncio future; the Ruby port blocks the calling thread on a
      # ConditionVariable, mirroring +#wait_for_ended+'s synchronization
      # model.
      #
      # @param event_type [String] the RELAY event type to wait for
      # @param predicate [#call, nil] optional filter +->(event) { ... }+
      # @param timeout [Numeric, nil] optional timeout in seconds
      # @return [RelayEvent, nil] the matching event, or +nil+ on timeout
      def wait_for(event_type, predicate: nil, timeout: nil)
        mutex     = Mutex.new
        cv        = ConditionVariable.new
        result    = nil
        satisfied = false

        handler = lambda do |event|
          mutex.synchronize do
            next if satisfied
            next unless predicate.nil? || predicate.call(event)

            result    = event
            satisfied = true
            cv.broadcast
          end
        end

        on(event_type, &handler)
        begin
          mutex.synchronize do
            if timeout
              deadline = Time.now + timeout
              until satisfied
                remaining = deadline - Time.now
                break if remaining <= 0

                cv.wait(mutex, remaining)
              end
            else
              cv.wait(mutex) until satisfied
            end
          end
          result
        ensure
          # Remove the one-shot listener so it doesn't fire for later events.
          @mutex.synchronize do
            listeners = @listeners[event_type]
            listeners.delete(handler) if listeners
          end
        end
      end

      # ------------------------------------------------------------------
      # Action helper
      # ------------------------------------------------------------------

      def _start_action(action, method, params, on_completed: nil)
        if @state == CALL_STATE_ENDED
          $stderr.puts "[RELAY] Call #{@call_id} already ended, skipping #{method}"
          gone_event = RelayEvent.new(event_type: '', params: {})
          action._resolve(gone_event)
          return action
        end
        action._set_on_completed(on_completed) if on_completed
        @actions[action.control_id] = action
        begin
          result = _execute(method, params)
        rescue => exc
          @actions.delete(action.control_id)
          action._resolve(RelayEvent.new(event_type: '', params: {}))
          raise
        end
        # _execute returns {} when the call is gone (404/410)
        if result.nil? || result.empty?
          @actions.delete(action.control_id)
          unless action.done?
            gone_event = RelayEvent.new(event_type: '', params: {})
            action._resolve(gone_event)
          end
        end
        action
      end

      # ------------------------------------------------------------------
      # Call lifecycle methods
      # ------------------------------------------------------------------

      def answer(**kwargs)
        _execute('answer', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

      def hangup(reason: 'hangup')
        _execute('end', { 'reason' => reason })
      end

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

      def disconnect
        _execute('disconnect')
      end

      # ------------------------------------------------------------------
      # Hold / Unhold
      # ------------------------------------------------------------------

      def hold
        _execute('hold')
      end

      def unhold
        _execute('unhold')
      end

      # ------------------------------------------------------------------
      # Denoise
      # ------------------------------------------------------------------

      def denoise
        _execute('denoise')
      end

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

      def ai_hold(**kwargs)
        _execute('ai_hold', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

      def ai_unhold(**kwargs)
        _execute('ai_unhold', kwargs.empty? ? nil : kwargs.transform_keys(&:to_s))
      end

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
        _start_action(action, 'play', params, on_completed: on_completed)
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
        _start_action(action, 'record', params, on_completed: on_completed)
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
        _start_action(action, 'play_and_collect', params, on_completed: on_completed)
      end

      def collect(collect_opts, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        params.merge!(collect_opts.transform_keys(&:to_s)) if collect_opts.is_a?(Hash)
        kwargs.each { |k, v| params[k.to_s] = v }
        action = StandaloneCollectAction.new(self, cid)
        _start_action(action, 'collect', params, on_completed: on_completed)
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
        _start_action(action, 'detect', params, on_completed: on_completed)
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
        _start_action(action, 'send_fax', params, on_completed: on_completed)
      end

      def receive_fax(control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = FaxAction.new(self, cid, 'receive_fax')
        _start_action(action, 'receive_fax', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Tap
      # ------------------------------------------------------------------

      def tap_audio(tap_opts, device:, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'tap' => tap_opts, 'device' => device }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = TapAction.new(self, cid)
        _start_action(action, 'tap', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Stream
      # ------------------------------------------------------------------

      def stream(url:, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'url' => url }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = StreamAction.new(self, cid)
        _start_action(action, 'stream', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Transcribe
      # ------------------------------------------------------------------

      def transcribe(control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = TranscribeAction.new(self, cid)
        _start_action(action, 'transcribe', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # Pay
      # ------------------------------------------------------------------

      def pay(payment_connector_url:, control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid, 'payment_connector_url' => payment_connector_url }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = PayAction.new(self, cid)
        _start_action(action, 'pay', params, on_completed: on_completed)
      end

      # ------------------------------------------------------------------
      # AI (returns AIAction)
      # ------------------------------------------------------------------

      def ai(control_id: nil, on_completed: nil, **kwargs)
        cid = control_id || SecureRandom.uuid
        params = { 'control_id' => cid }
        kwargs.each { |k, v| params[k.to_s] = v }
        action = AIAction.new(self, cid)
        _start_action(action, 'ai', params, on_completed: on_completed)
      end

      def to_s
        "Call(id=#{@call_id}, state=#{@state}, direction=#{@direction})"
      end

      def inspect
        to_s
      end
    end
  end
end
