# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Play < ControlComponent
    def initialize(call:, play:, volume: nil)
      super(call: call)
      @play = play
      @volume = volume
    end

    def method
      Relay::ComponentMethod::PLAY
    end

    def event_type
      Relay::CallNotification::PLAY
    end

    def inner_params
      prm = {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        play: @play
      }

      prm[:volume] = @volume unless @volume.nil?
      prm
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
      @call.broadcast "play_#{@state}".to_sym, event
      @call.broadcast :play_state_change, event
    end
  end
end
