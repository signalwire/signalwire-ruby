module Signalwire::Relay::Calling
  # A special component that only waits for call events
  #
  class Await < Component
    def event_type
      Relay::CallNotification::STATE
    end
    
    def notification_handler(event)
      @state = event.call_params[:call_state]
      @event = event
      @successful = true if @events_waiting.include?(@state)
      check_for_waiting_events
    end

    def execute
      setup_handlers
    end
  end
end