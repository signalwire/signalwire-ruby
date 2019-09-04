# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Component
    include Signalwire::Logger
    attr_reader :completed, :state, :successful, :event, :execute_result, :call

    def initialize(call:)
      @call = call
      @completed = false
      @successful = false
      @events_waiting = []
      @call.register_component(self)
    end

    # Relay method corresponding to the command
    #
    def method
      raise NotImplementedError, 'Define this method on the child classes'
    end

    # Relay payload
    # Implement this on child classes
    def payload
      nil
    end

    # The event type the subclass listens to
    def event_type
      raise NotImplementedError, 'Define this method on the child classes'
    end

    def execute_params(method_suffix = nil)
      {
        protocol: @call.client.protocol,
        method: method + method_suffix.to_s,
        params: inner_params
      }
    end

    def inner_params
      result = {
        node_id: @call.node_id,
        call_id: @call.id
      }
      result[:params] = payload if payload
      result
    end

    def execute
      setup_handlers
      @call.relay_execute execute_params do |event, outcome|
        handle_execute_result(event, outcome)
      end
    end

    def setup_handlers
      @call.on :event, event_type: event_type do |evt|
        notification_handler(evt)
      end
    end

    def handle_execute_result(event, outcome)
      @execute_result = event
      terminate if outcome == :failure
    end

    def terminate(event = nil)
      @completed = true
      @successful = false
      @state = 'failed'
      @event = event if event
      blocker&.reject false
    end

    def setup_waiting_events(events)
      @events_waiting = events
    end

    def wait_for(*events)
      setup_waiting_events(events)
      execute
      wait_on_blocker unless @completed
    end

    def wait_on_blocker
      create_blocker
      blocker.wait
    end

    def has_blocker?
      !@blocker.nil?
    end

    # This is the most important method to implement in a subclass
    #
    def notification_handler(_event)
      # to be implemented by subclasses. An example could be:
      #
      # if event.call_params[:call_state] == 'ended'
      #   unblock
      # end
      raise NotImplementedError, 'Define this method on the child classes'
    end

    def create_blocker
      @blocker = Concurrent::Promises.resolvable_future
    end

    def unblock(value)
      blocker&.resolve value if has_blocker? && blocker.pending?
    end

    attr_reader :blocker

    def check_for_waiting_events
      unblock(event) if @events_waiting.include?(@state)
    end
  end
end
