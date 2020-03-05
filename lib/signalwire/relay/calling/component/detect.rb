# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Detect < ControlComponent
    attr_reader :result, :type

    FINISHED_EVENTS = [
      Relay::CallDetectState::FINISHED, 
      Relay::CallDetectState::ERROR,
      Relay::CallDetectState::READY,
      Relay::CallDetectState::NOT_READY,
      Relay::CallDetectState::MACHINE,
      Relay::CallDetectState::HUMAN,
      Relay::CallDetectState::UNKNOWN
    ]

    READY_EVENTS = [
      Relay::CallDetectState::FINISHED, 
      Relay::CallDetectState::ERROR,
      Relay::CallDetectState::READY,
      Relay::CallDetectState::HUMAN
    ]

    MACHINE_EVENTS = [Relay::CallDetectState::READY, Relay::CallDetectState::NOT_READY]

    def initialize(call:, detect:, wait_for_beep: false, timeout: 30)
      super(call: call)
      @detect = detect
      @timeout = timeout
      @wait_for_beep = wait_for_beep
      @received_events = Concurrent::Array.new
      @waiting_for_ready = false
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
      detect_result = event.call_params[:detect]
      @type = detect_result[:type]
      params = detect_result[:params]
      @state = params[:event]

      # if we are detecting digits we are done
      return complete(event) if @type == Relay::CallDetectType::DIGIT

      if @type == 'machine'
        if @wait_for_beep
          return complete(event) if READY_EVENTS.include?(@state)
        else
          return complete(event) if FINISHED_EVENTS.include?(@state)
        end
      else
        check_for_waiting_events
      end
      
      @received_events << @state
      broadcast_event(event)
    end

    def broadcast_event(event)
      @call.broadcast "detect_#{@state}".to_sym, event
      @call.broadcast :detect_state_change, event
    end

    private

    def complete(event)
      @completed = true
      @event = event
      @result = @state

      @successful = @state != Relay::CallDetectState::ERROR
      unblock(event) if has_blocker?
    end
  end
end
