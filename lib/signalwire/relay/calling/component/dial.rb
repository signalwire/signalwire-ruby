# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Dial < Component
    def method
      Relay::ComponentMethod::DIAL
    end

    def event_type
      Relay::CallNotification::STATE
    end

    def inner_params
      {
        tag: @call.tag,
        device: @call.device
      }
    end

    def notification_handler(event)
      @state = event.call_params[:call_state]

      ended_events = [Relay::CallState::ANSWERED, Relay::CallState::ENDING, Relay::CallState::ENDED]

      if ended_events.include?(@state)
        @completed = true
        @successful = true if @state == Relay::CallState::ANSWERED
        @event = event
      end

      check_for_waiting_events
    end
  end
end
