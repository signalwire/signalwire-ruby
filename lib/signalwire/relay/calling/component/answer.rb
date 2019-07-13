# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Answer < Component
    def method
      Relay::ComponentMethod::ANSWER
    end

    def event_type
      Relay::CallNotification::STATE
    end

    def notification_handler(event)
      @state = event.call_params[:call_state]

      ended_events = [Relay::CallState::ANSWERED]

      if ended_events.include?(@state)
        @completed = true
        @successful = true
        @event = event
      end

      check_for_waiting_events
    end
  end
end
