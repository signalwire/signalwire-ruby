# frozen_string_literal: true

require 'json'
require_relative 'constants'

module SignalWire
  module Relay
    # JSON serialization, Ruby pattern-matching, and value-equality for
    # {Message}. Extracted into a mixin so {Message} itself stays focused on
    # lifecycle/completion. Relies on the host defining {#to_h} and the
    # @message_id/@direction/@state ivars.
    module MessageSerialization
      def to_s
        "Message(id=#{@message_id}, direction=#{@direction}, " \
          "state=#{@state}, from=#{@from_number}, to=#{@to_number})"
      end

      def inspect
        to_s
      end

      # @return [String] JSON serialization of {#to_h}.
      def to_json(*)
        to_h.to_json(*)
      end

      # Ruby 3.0 pattern matching: +case msg; in { direction:, body: }+.
      # @param keys [Array<Symbol>, nil]
      # @return [Hash{Symbol => Object}]
      def deconstruct_keys(keys)
        h = to_h
        return h if keys.nil?

        keys.each_with_object({}) do |k, acc|
          acc[k] = h[k] if h.key?(k)
        end
      end

      # Array pattern matching: the stable identity triple.
      # @return [Array]
      def deconstruct
        [@message_id, @direction, @state]
      end

      # Value equality over the message's data (ignores completion state).
      def ==(other)
        other.is_a?(Message) && to_h == other.to_h
      end
      alias eql? ==

      # Hash key consistent with {#==} so equal messages share a bucket.
      def hash
        [self.class, to_h].hash
      end
    end

    # Represents a single SMS/MMS message.
    #
    # For outbound messages, use message.wait to block until a terminal state
    # (delivered, undelivered, failed) is reached.
    class Message
      attr_reader :message_id, :context, :direction, :from_number, :to_number, :body, :media, :segments, :tags,
                  :reason, :result
      attr_accessor :state

      def initialize(message_id: '', context: '', direction: '', from_number: '',
                     to_number: '', body: '', media: nil, segments: 0,
                     state: '', reason: '', tags: nil)
        assign_value_fields(message_id:, context:, direction:, from_number:, to_number:,
                            body:, media:, segments:, state:, reason:, tags:)
        init_completion_tracking
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
      #
      # The handler is REQUIRED, matching the reference
      # (``Message.on(self, handler: Callable[[RelayEvent], Any])``). Ruby's
      # block IS the handler; supplying neither registers nothing and raises.
      def on_event(handler, &block)
        callback = block || handler
        raise ArgumentError, 'on_event requires a handler (block or callable)' if callback.nil?

        @listeners << callback
      end

      def done?
        @done
      end

      alias is_done? done?

      # Typed predicate over {#state}, alongside the bare string. Agrees with
      # {MessageState.terminal?} — true once the message has reached a final
      # delivery outcome (delivered / undelivered / failed), which is exactly
      # when {#wait} unblocks.
      #
      # @return [Boolean]
      def terminal?
        MessageState.terminal?(@state)
      end

      # Wait for the message to reach a terminal state.
      # Raises ActionTimeoutError if timeout exceeded.
      def wait(timeout: nil)
        @mutex.synchronize do
          return @result if @done

          timeout ? wait_until_done(timeout) : (@condition.wait(@mutex) until @done)
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
        notify_listeners(event)

        # Check terminal state
        _resolve(event) if MessageState.terminal?(new_state)
      end

      # Semantic Hash view of the message's value fields (the completion
      # machinery — mutex/condition/callbacks — is excluded). Symbol keys,
      # idiomatic for Ruby. @return [Hash{Symbol => Object}]
      def to_h
        {
          message_id: @message_id, context: @context, direction: @direction,
          from_number: @from_number, to_number: @to_number, body: @body,
          media: @media, segments: @segments, state: @state,
          reason: @reason, tags: @tags
        }
      end

      include MessageSerialization

      private

      def notify_listeners(event)
        @listeners.each do |handler|
          handler.call(event)
        rescue StandardError => e
          warn "[RELAY] Error in message event handler for #{@message_id}: #{e.message}"
        end
      end

      # Caller holds @mutex. Blocks until @done or raises on timeout.
      def wait_until_done(timeout)
        deadline = Time.now + timeout
        until @done
          remaining = deadline - Time.now
          raise ActionTimeoutError, "Message #{@message_id} timed out after #{timeout}s" if remaining <= 0

          @condition.wait(@mutex, remaining)
        end
      end

      def assign_value_fields(**fields)
        fields[:media] = fields[:media] || []
        fields[:tags]  = fields[:tags] || []
        fields.each { |name, value| instance_variable_set("@#{name}", value) }
      end

      def init_completion_tracking
        @mutex        = Mutex.new
        @condition    = ConditionVariable.new
        @done         = false
        @result       = nil
        @on_completed = nil
        @listeners    = []
      end

      def _resolve(event)
        @mutex.synchronize do
          return if @done

          @result = event
          @done   = true
          @condition.broadcast
        end
        invoke_on_completed(event)
      end

      def invoke_on_completed(event)
        return unless @on_completed

        @on_completed.call(event)
      rescue StandardError => e
        warn "[RELAY] Error in on_completed callback for message #{@message_id}: #{e.message}"
      end
    end
  end
end
