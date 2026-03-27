# frozen_string_literal: true

module SignalWire
  module Relay
    # Represents a single SMS/MMS message.
    #
    # For outbound messages, use message.wait to block until a terminal state
    # (delivered, undelivered, failed) is reached.
    class Message
      attr_reader :message_id, :context, :direction, :from_number, :to_number,
                  :body, :media, :segments, :tags, :reason
      attr_accessor :state

      def initialize(message_id: '', context: '', direction: '', from_number: '',
                     to_number: '', body: '', media: nil, segments: 0,
                     state: '', reason: '', tags: nil)
        @message_id  = message_id
        @context     = context
        @direction   = direction
        @from_number = from_number
        @to_number   = to_number
        @body        = body
        @media       = media || []
        @segments    = segments
        @state       = state
        @reason      = reason
        @tags        = tags || []

        # Completion tracking
        @mutex        = Mutex.new
        @condition    = ConditionVariable.new
        @done         = false
        @result       = nil
        @on_completed = nil
        @listeners    = []
      end

      # Set the on_completed callback.
      def on_completed(&block)
        @on_completed = block
      end

      # Set the on_completed callback from options.
      def _set_on_completed(callback)
        @on_completed = callback
      end

      # Register an event listener for state changes.
      def on_event(&handler)
        @listeners << handler
      end

      def done?
        @done
      end

      alias_method :is_done?, :done?

      def result
        @result
      end

      # Wait for the message to reach a terminal state.
      # Raises ActionTimeoutError if timeout exceeded.
      def wait(timeout: nil)
        @mutex.synchronize do
          return @result if @done

          if timeout
            deadline = Time.now + timeout
            while !@done
              remaining = deadline - Time.now
              if remaining <= 0
                raise ActionTimeoutError, "Message #{@message_id} timed out after #{timeout}s"
              end
              @condition.wait(@mutex, remaining)
            end
          else
            @condition.wait(@mutex) until @done
          end
          @result
        end
      end

      # Handle a messaging.state event for this message.
      def _dispatch_event(payload)
        event_params = payload['params'] || {}
        new_state = event_params['message_state'] || ''

        @state  = new_state unless new_state.empty?
        @reason = event_params['reason'] if event_params.key?('reason')

        event = Relay.parse_event(payload)

        # Notify listeners
        @listeners.each do |handler|
          begin
            handler.call(event)
          rescue => e
            $stderr.puts "[RELAY] Error in message event handler for #{@message_id}: #{e.message}"
          end
        end

        # Check terminal state
        _resolve(event) if MESSAGE_TERMINAL_STATES.include?(new_state)
      end

      def to_s
        "Message(id=#{@message_id}, direction=#{@direction}, " \
          "state=#{@state}, from=#{@from_number}, to=#{@to_number})"
      end

      def inspect
        to_s
      end

      private

      def _resolve(event)
        @mutex.synchronize do
          return if @done

          @result = event
          @done   = true
          @condition.broadcast
        end
        if @on_completed
          begin
            @on_completed.call(event)
          rescue => e
            $stderr.puts "[RELAY] Error in on_completed callback for message #{@message_id}: #{e.message}"
          end
        end
      end
    end
  end
end
