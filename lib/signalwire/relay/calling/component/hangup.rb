# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Hangup < Component
    def initialize(call:, reason:)
      super(call: call)
      @reason = reason
    end

    def method
      Relay::ComponentMethod::HANGUP
    end

    def event_type
      Relay::CallNotification::STATE
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        reason: @reason
      }
    end

    def notification_handler(event)
      @state = event.call_params[:call_state]
      end_reason = event.call_params[:call_state]

      @completed = @state == Relay::CallState::ENDED

      if @completed
        @successful = true
        @reason = end_reason
        @event = event
      end

      check_for_waiting_events
    end
  end
end
