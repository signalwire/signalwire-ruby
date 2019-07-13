# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Connect < Component
    def initialize(call:, devices:)
      super(call: call)
      @devices = devices
    end

    def method
      Relay::ComponentMethod::CONNECT
    end

    def event_type
      Relay::CallNotification::CONNECT
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        devices: @devices
      }
    end

    def notification_handler(event)
      @state = event.call_params[:connect_state]

      @completed = @state != Relay::CallConnectState::CONNECTING

      if @completed
        @successful = @state == Relay::CallConnectState::CONNECTED
        @event = event
      end

      check_for_waiting_events
    end
  end
end
