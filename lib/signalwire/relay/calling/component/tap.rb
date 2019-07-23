# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Tap < ControlComponent
    def initialize(call:, tap:, device:)
      super(call: call)
      @tap = tap
      @device = device
    end

    def method
      Relay::ComponentMethod::TAP
    end

    def event_type
      Relay::CallNotification::TAP
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        tap: @tap,
        device: @device
      }
    end

    def notification_handler(event)
      @state = event.call_params[:state]

      @completed = @state != Relay::CallPlayState::PLAYING

      if @completed
        @successful = true if @state == Relay::CallPlayState::FINISHED
        @event = event
      end

      broadcast_event(event)
      check_for_waiting_events
    end

    def broadcast_event(event)
      @call.broadcast "tap_#{@state}".to_sym, event
      @call.broadcast :tap_state_change, event
    end
  end
end

const { state, tap, device } = params
    this.tap = tap
    this.device = device
    this.state = state

    this.completed = this.state === CallTapState.Finished
    if (this.completed) {
      this.successful = true
      this.event = new Event(this.state, params)
    }