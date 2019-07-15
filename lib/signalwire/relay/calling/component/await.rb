module Signalwire::Relay::Calling
  # A special component that only waits for call events
  #
  class Await < Component
    
    def notification_handler(event)
      check_for_waiting_events
    end

    def execute
      setup_handlers
    end
  end