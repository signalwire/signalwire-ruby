# frozen_string_literal: true

require 'securerandom'
require_relative '../error'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Relay — the RELAY realtime (WebSocket / JSON-RPC 2.0) client surface.
  module Relay
    # Raised when an action times out waiting for completion.
    class ActionTimeoutError < SignalWire::Error; end

    # Base class for async action handles (play, record, detect, etc.).
    #
    # Holds a control_id and back-reference to the Call. Resolves when the
    # server sends a terminal event for this control_id.
    #
    # Uses Ruby's Queue for blocking wait semantics.
    class Action
      attr_reader :control_id, :call, :result, :completed

      # @param call [Call] the call this action runs on; used to send the RELAY
      #   control methods (stop / pause / resume / volume)
      # @param control_id [String] the id the server echoes on every event for this
      #   operation; how {#_check_event} recognizes its own events
      # @param terminal_event [String] the RELAY event type that carries this
      #   action's state transitions, e.g. `"calling.call.play"`
      # @param terminal_states [Array<String>] the states that complete the action;
      #   seeing any of them resolves the wait and fires the on-completed callback
      def initialize(call, control_id, terminal_event, terminal_states)
        @call             = call
        @control_id       = control_id
        @terminal_event   = terminal_event
        @terminal_states  = terminal_states
        @result           = nil
        @completed        = false
        @mutex            = Mutex.new
        @condition        = ConditionVariable.new
        @on_completed     = nil
      end

      # Set the on_completed callback.
      def on_completed(&block)
        @on_completed = block
      end

      # Called internally to set the on_completed callback from options.
      def _set_on_completed(callback)
        @on_completed = callback
      end

      # Called by Call when an event matches our control_id.
      def _check_event(event)
        state = event.params['state'] || ''
        return unless @terminal_states.include?(state) && !@completed

        _resolve(event)
      end

      # Mark the action as completed and fire the on_completed callback.
      def _resolve(event)
        @mutex.synchronize do
          return if @completed

          @result    = event
          @completed = true
          @condition.broadcast
        end
        fire_on_completed(event)
      end

      # Wait for the action to complete. Returns the terminal event.
      # Raises ActionTimeoutError if timeout is specified and exceeded.
      def wait(timeout: nil)
        @mutex.synchronize do
          return @result if @completed

          if timeout
            wait_with_timeout(timeout)
          else
            @condition.wait(@mutex) until @completed
          end
          @result
        end
      end

      # Whether the server has already sent a terminal event for this action.
      # Non-blocking, unlike {#wait}.
      #
      # @return [Boolean]
      def done?
        @completed
      end

      alias is_done? done?

      private

      # Fire the on_completed callback outside the mutex, swallowing errors.
      def fire_on_completed(event)
        return unless @on_completed

        begin
          @on_completed.call(event)
        rescue StandardError => e
          warn "[RELAY] Error in on_completed callback for #{@control_id}: #{e.message}"
        end
      end

      # Block on the condition variable until completed or the deadline passes.
      def wait_with_timeout(timeout)
        deadline = Time.now + timeout
        until @completed
          remaining = deadline - Time.now
          raise ActionTimeoutError, "Action #{@control_id} timed out after #{timeout}s" if remaining <= 0

          @condition.wait(@mutex, remaining)
        end
      end
    end

    # Handle for an active play operation.
    class PlayAction < Action
      # @param call [Call] the call the playback runs on
      # @param control_id [String] the id the server echoes on `calling.call.play` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_PLAY,
              [PLAY_STATE_FINISHED, PLAY_STATE_ERROR])
      end

      # Stop the playback by sending the RELAY `play.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('play.stop', { 'control_id' => @control_id })
      end

      # Pause the playback via the RELAY `play.pause` method.
      #
      # @param behavior [String, nil] what to do with the media while paused;
      #   omitted from the wire params when nil, leaving the server default
      def pause(behavior: nil)
        params = { 'control_id' => @control_id }
        params['behavior'] = behavior if behavior
        @call._execute('play.pause', params)
      end

      # Resume a paused playback via the RELAY `play.resume` method.
      def resume
        @call._execute('play.resume', { 'control_id' => @control_id })
      end

      # Change the playback volume of the playback via the RELAY `play.volume` method.
      #
      # @param vol [Numeric] the new volume, sent as the `volume` wire param
      def volume(vol)
        @call._execute('play.volume', { 'control_id' => @control_id, 'volume' => vol })
      end
    end

    # Handle for an active record operation.
    class RecordAction < Action
      # @param call [Call] the call being recorded
      # @param control_id [String] the id the server echoes on `calling.call.record` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_RECORD,
              [RECORD_STATE_FINISHED, RECORD_STATE_NO_INPUT])
      end

      # Stop the recording by sending the RELAY `record.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('record.stop', { 'control_id' => @control_id })
      end

      # Pause the recording via the RELAY `record.pause` method.
      #
      # @param behavior [String, nil] what to do with the media while paused;
      #   omitted from the wire params when nil, leaving the server default
      def pause(behavior: nil)
        params = { 'control_id' => @control_id }
        params['behavior'] = behavior if behavior
        @call._execute('record.pause', params)
      end

      # Resume a paused a recording via the RELAY `record.resume` method.
      def resume
        @call._execute('record.resume', { 'control_id' => @control_id })
      end
    end

    # Handle for an active detect operation.
    class DetectAction < Action
      # @param call [Call] the call being analysed
      # @param control_id [String] the id the server echoes on `calling.call.detect` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_DETECT, %w[finished error])
      end

      # Detect delivers results continuously. Resolve on first result or
      # when finished/error.
      # Resolve on the FIRST event carrying a non-empty `detect` result, not only on
      # a terminal state — detect streams results continuously, so waiting for
      # `finished` would discard the answer the caller asked for.
      #
      # @param event [RelayEvent] a `calling.call.detect` event for this control_id
      def _check_event(event)
        detect = event.params['detect'] || {}
        state  = event.params['state'] || ''
        return unless (!detect.empty? || @terminal_states.include?(state)) && !@completed

        _resolve(event)
      end

      # Stop the detector by sending the RELAY `detect.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('detect.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for play_and_collect or standalone collect.
    class CollectAction < Action
      # @param call [Call] the call the play-and-collect runs on
      # @param control_id [String] the id the server echoes on `calling.call.collect` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_COLLECT,
              %w[finished error no_input no_match])
      end

      # play_and_collect shares a control_id across play and collect
      # phases. Only resolve on collect events, not play events.
      # Resolve only on collect events. `play_and_collect` shares one control_id
      # across its play and collect phases, so a play event carrying the same id
      # must not complete the collect. A non-empty `result` resolves immediately;
      # otherwise the base terminal-state check applies.
      #
      # @param event [RelayEvent] an event carrying this action's control_id
      def _check_event(event)
        return unless event.event_type == EVENT_CALL_COLLECT

        result_data = event.params['result'] || {}
        if !result_data.empty? && !@completed
          _resolve(event)
        else
          super
        end
      end

      # Stop the play-and-collect by sending the RELAY `play_and_collect.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('play_and_collect.stop', { 'control_id' => @control_id })
      end

      # Pause the play-and-collect prompt via the RELAY `play_and_collect.pause` method.
      #
      # @param behavior [String, nil] what to do with the media while paused;
      #   omitted from the wire params when nil, leaving the server default
      def pause(behavior: nil)
        params = { 'control_id' => @control_id }
        params['behavior'] = behavior if behavior
        @call._execute('play_and_collect.pause', params)
      end

      # Resume a paused play-and-collect prompt via the RELAY `play_and_collect.resume` method.
      def resume
        @call._execute('play_and_collect.resume', { 'control_id' => @control_id })
      end

      # Change the playback volume of the play-and-collect prompt via the RELAY `play_and_collect.volume` method.
      #
      # @param vol [Numeric] the new volume, sent as the `volume` wire param
      def volume(vol)
        @call._execute('play_and_collect.volume', {
                         'control_id' => @control_id, 'volume' => vol
                       })
      end

      # Start the collect's inter-digit and no-input timers via the RELAY
      # `collect.start_input_timers` method. Use it when the prompt was played
      # outside this collect, so the timers begin when the caller could actually
      # have started speaking.
      def start_input_timers
        @call._execute('collect.start_input_timers', { 'control_id' => @control_id })
      end
    end

    # Handle for standalone calling.collect (without play).
    class StandaloneCollectAction < Action
      # @param call [Call] the call the collect runs on
      # @param control_id [String] the id the server echoes on `calling.call.collect` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_COLLECT,
              %w[finished error no_input no_match])
      end

      # Resolve on a collect event carrying either a non-empty `result` or a
      # terminal state (finished / error / no_input / no_match). Events for other
      # event types sharing this control_id are ignored.
      #
      # @param event [RelayEvent] an event carrying this action's control_id
      def _check_event(event)
        return unless event.event_type == EVENT_CALL_COLLECT

        result_data = event.params['result'] || {}
        state       = event.params['state'] || ''
        return unless (!result_data.empty? || @terminal_states.include?(state)) && !@completed

        _resolve(event)
      end

      # Stop the collect by sending the RELAY `collect.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('collect.stop', { 'control_id' => @control_id })
      end

      # Start the collect's inter-digit and no-input timers via the RELAY
      # `collect.start_input_timers` method, for when the prompt was played outside
      # this collect.
      def start_input_timers
        @call._execute('collect.start_input_timers', { 'control_id' => @control_id })
      end
    end

    # Handle for send_fax or receive_fax.
    class FaxAction < Action
      # @param call [Call] the call carrying the fax
      # @param control_id [String] the id the server echoes on `calling.call.fax` events
      # @param method_prefix [String] `"send_fax"` or `"receive_fax"` — which RELAY
      #   method family {#stop} addresses, since one class handles both directions
      def initialize(call, control_id, method_prefix)
        super(call, control_id, EVENT_CALL_FAX, %w[finished error])
        @method_prefix = method_prefix
      end

      # Stop the fax by sending `<method_prefix>.stop` — `send_fax.stop` or
      # `receive_fax.stop` depending on which direction this action was created for.
      def stop
        @call._execute("#{@method_prefix}.stop", { 'control_id' => @control_id })
      end
    end

    # Handle for an active tap operation.
    class TapAction < Action
      # @param call [Call] the call being tapped
      # @param control_id [String] the id the server echoes on `calling.call.tap` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_TAP, %w[finished])
      end

      # Stop the media tap by sending the RELAY `tap.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('tap.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active stream operation.
    class StreamAction < Action
      # @param call [Call] the call being streamed
      # @param control_id [String] the id the server echoes on `calling.call.stream` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_STREAM, %w[finished])
      end

      # Stop the media stream by sending the RELAY `stream.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('stream.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active pay operation.
    class PayAction < Action
      # @param call [Call] the call the payment session runs on
      # @param control_id [String] the id the server echoes on `calling.call.pay` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_PAY, %w[finished error])
      end

      # Stop the payment session by sending the RELAY `pay.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('pay.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active transcribe operation.
    class TranscribeAction < Action
      # @param call [Call] the call being transcribed
      # @param control_id [String] the id the server echoes on `calling.call.transcribe` events
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_TRANSCRIBE, %w[finished])
      end

      # Stop the transcription by sending the RELAY `transcribe.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('transcribe.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active AI agent session.
    class AIAction < Action
      # @param call [Call] the call the AI agent is attached to
      # @param control_id [String] the id the server echoes on `calling.call.ai` events
      def initialize(call, control_id)
        super(call, control_id, 'calling.call.ai', %w[finished error])
      end

      # Stop the AI agent session by sending the RELAY `ai.stop` method with this
      # action's control_id. Does not block — the action resolves when the
      # server's terminal event arrives.
      def stop
        @call._execute('ai.stop', { 'control_id' => @control_id })
      end
    end
  end
end
