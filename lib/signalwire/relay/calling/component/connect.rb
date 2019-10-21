# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Connect < Component
    def initialize(call:, devices:, ringback: nil)
      super(call: call)
      @devices = devices
      @ringback = ringback
    end

    def method
      Relay::ComponentMethod::CONNECT
    end

    def event_type
      Relay::CallNotification::CONNECT
    end

    def inner_params
      params = {
        node_id: @call.node_id,
        call_id: @call.id,
        devices: @devices
      }

      params[:ringback] = @ringback unless @ringback.nil?
      params
    end

    def notification_handler(event)
      @state = event.call_params[:connect_state]

      @completed = @state != Relay::CallConnectState::CONNECTING

      if @completed
        @successful = @state == Relay::CallConnectState::CONNECTED
        @event = event
      end

      broadcast_event(event)
      check_for_waiting_events
    end

    def broadcast_event(event)
      @call.broadcast "connect_#{@state}".to_sym, event
      @call.broadcast :connect_state_change, event
    end
  end
end
