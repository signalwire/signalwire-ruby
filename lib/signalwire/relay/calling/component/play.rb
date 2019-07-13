# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Play < ControlComponent
    def initialize(call:, play:)
      super(call: call)
      @play = play
    end

    def method
      Relay::ComponentMethod::PLAY
    end

    def event_type
      Relay::CallNotification::PLAY
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        play: @play
      }
    end

    def notification_handler(event)
      @state = event.call_params[:state]

      @completed = @state != Relay::CallPlayState::PLAYING

      if @completed
        @successful = true if @state == Relay::CallPlayState::FINISHED
        @event = event
      end

      check_for_waiting_events
    end
  end
end
