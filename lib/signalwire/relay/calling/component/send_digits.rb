module Signalwire::Relay::Calling
  class SendDigits < ControlComponent
    def initialize(call:, digits:)
      super(call: call)
      @digits = digits
    end

    def method
      Relay::ComponentMethod::SEND_DIGITS
    end

    def event_type
      Relay::CallNotification::SEND_DIGITS
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        digits: @digits
      }
    end

    def notification_handler(event)
      @state = event.call_params[:state]

      @completed = @state == Relay::CallSendDigitsState::FINISHED
      @successful = @completed
      @event = event

      broadcast_event(event)
      check_for_waiting_events
    end

    def broadcast_event(event)
      @call.broadcast "send_digits_#{@state}".to_sym, event
      @call.broadcast :send_digits_change, event
    end

    def stop
      logger.warn "SendDigits does not implement a stop action"
    end
  end
end