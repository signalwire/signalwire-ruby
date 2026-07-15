# frozen_string_literal: true

require 'securerandom'

module SignalWire
  module Relay
    # Raised when an action times out waiting for completion.
    class ActionTimeoutError < StandardError; end

    # Base class for async action handles (play, record, detect, etc.).
    #
    # Holds a control_id and back-reference to the Call. Resolves when the
    # server sends a terminal event for this control_id.
    #
    # Uses Ruby's Queue for blocking wait semantics.
    class Action
      attr_reader :control_id, :call, :result, :completed

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
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_PLAY,
              [PLAY_STATE_FINISHED, PLAY_STATE_ERROR])
      end

      def stop
        @call._execute('play.stop', { 'control_id' => @control_id })
      end

      def pause(behavior: nil)
        params = { 'control_id' => @control_id }
        params['behavior'] = behavior if behavior
        @call._execute('play.pause', params)
      end

      def resume
        @call._execute('play.resume', { 'control_id' => @control_id })
      end

      def volume(vol)
        @call._execute('play.volume', { 'control_id' => @control_id, 'volume' => vol })
      end
    end

    # Handle for an active record operation.
    class RecordAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_RECORD,
              [RECORD_STATE_FINISHED, RECORD_STATE_NO_INPUT])
      end

      def stop
        @call._execute('record.stop', { 'control_id' => @control_id })
      end

      def pause(behavior: nil)
        params = { 'control_id' => @control_id }
        params['behavior'] = behavior if behavior
        @call._execute('record.pause', params)
      end

      def resume
        @call._execute('record.resume', { 'control_id' => @control_id })
      end
    end

    # Handle for an active detect operation.
    class DetectAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_DETECT, %w[finished error])
      end

      # Detect delivers results continuously. Resolve on first result or
      # when finished/error.
      def _check_event(event)
        detect = event.params['detect'] || {}
        state  = event.params['state'] || ''
        return unless (!detect.empty? || @terminal_states.include?(state)) && !@completed

        _resolve(event)
      end

      def stop
        @call._execute('detect.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for play_and_collect or standalone collect.
    class CollectAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_COLLECT,
              %w[finished error no_input no_match])
      end

      # play_and_collect shares a control_id across play and collect
      # phases. Only resolve on collect events, not play events.
      def _check_event(event)
        return unless event.event_type == EVENT_CALL_COLLECT

        result_data = event.params['result'] || {}
        if !result_data.empty? && !@completed
          _resolve(event)
        else
          super
        end
      end

      def stop
        @call._execute('play_and_collect.stop', { 'control_id' => @control_id })
      end

      def pause(behavior: nil)
        params = { 'control_id' => @control_id }
        params['behavior'] = behavior if behavior
        @call._execute('play_and_collect.pause', params)
      end

      def resume
        @call._execute('play_and_collect.resume', { 'control_id' => @control_id })
      end

      def volume(vol)
        @call._execute('play_and_collect.volume', {
                         'control_id' => @control_id, 'volume' => vol
                       })
      end

      def start_input_timers
        @call._execute('collect.start_input_timers', { 'control_id' => @control_id })
      end
    end

    # Handle for standalone calling.collect (without play).
    class StandaloneCollectAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_COLLECT,
              %w[finished error no_input no_match])
      end

      def _check_event(event)
        return unless event.event_type == EVENT_CALL_COLLECT

        result_data = event.params['result'] || {}
        state       = event.params['state'] || ''
        return unless (!result_data.empty? || @terminal_states.include?(state)) && !@completed

        _resolve(event)
      end

      def stop
        @call._execute('collect.stop', { 'control_id' => @control_id })
      end

      def start_input_timers
        @call._execute('collect.start_input_timers', { 'control_id' => @control_id })
      end
    end

    # Handle for send_fax or receive_fax.
    class FaxAction < Action
      def initialize(call, control_id, method_prefix)
        super(call, control_id, EVENT_CALL_FAX, %w[finished error])
        @method_prefix = method_prefix
      end

      def stop
        @call._execute("#{@method_prefix}.stop", { 'control_id' => @control_id })
      end
    end

    # Handle for an active tap operation.
    class TapAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_TAP, %w[finished])
      end

      def stop
        @call._execute('tap.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active stream operation.
    class StreamAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_STREAM, %w[finished])
      end

      def stop
        @call._execute('stream.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active pay operation.
    class PayAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_PAY, %w[finished error])
      end

      def stop
        @call._execute('pay.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active transcribe operation.
    class TranscribeAction < Action
      def initialize(call, control_id)
        super(call, control_id, EVENT_CALL_TRANSCRIBE, %w[finished])
      end

      def stop
        @call._execute('transcribe.stop', { 'control_id' => @control_id })
      end
    end

    # Handle for an active AI agent session.
    class AIAction < Action
      def initialize(call, control_id)
        super(call, control_id, 'calling.call.ai', %w[finished error])
      end

      def stop
        @call._execute('ai.stop', { 'control_id' => @control_id })
      end
    end
  end
end
