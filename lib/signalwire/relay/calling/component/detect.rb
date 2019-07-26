# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Detect < ControlComponent
    attr_reader :result, :type

    def initialize(call:, detect:, timeout: 30)
      super(call: call)
      @detect = detect
      @timeout = timeout
      @received_events = Concurrent::Array.new
    end

    def method
      Relay::ComponentMethod::DETECT
    end

    def event_type
      Relay::CallNotification::DETECT
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        detect: @detect,
        timeout: @timeout
      }
    end

    def notification_handler(event)
      result = event.call_params[:detect]
      @type = result[:type]
      params = result[:params]
      res_event = params[:event]
      @state = res_event

      if @state != Relay::CallDetectState::FINISHED && @state != Relay::CallDetectState::ERROR
        @received_events << res_event
      end

      @completed = @events_waiting.include?(@state)

      if @completed
        @successful = @state != Relay::CallDetectState::ERROR
        @result = @received_events.join(' ')
        @event = event
        unblock(event)
      end

      broadcast_event(event)
      # This component has complex logic so we handle it separately
      # check_for_waiting_events
    end

    def broadcast_event(event)
      @call.broadcast "detect_#{@state}".to_sym, event
      @call.broadcast :detect_state_change, event
    end
  end
end