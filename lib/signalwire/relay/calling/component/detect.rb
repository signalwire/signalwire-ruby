# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Detect < ControlComponent
    attr_reader :result, :type

    FINISHED_EVENTS = [Relay::CallDetectState::FINISHED, Relay::CallDetectState::ERROR]
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
      res_event = params[:event]
      @state = res_event

      return complete(event) if FINISHED_EVENTS.include?(@state) || @type == Relay::CallDetectType::DIGIT

      if has_blocker?
        @received_events << @state 
        return
      end

      if @waiting_for_ready
        return (@state == Relay::CallDetectState::READY ? complete(event) : nil)
      end

      if (@wait_for_beep && @state == Relay::CallDetectState::MACHINE)
        @waiting_for_ready = true
        return
      end
      
      check_for_waiting_events
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
      
      if has_blocker?
        @successful = !FINISHED_EVENTS.include?(@state)

        if MACHINE_EVENTS.include?(@state)
          @result = Relay::CallDetectState::MACHINE
        else
          @result = @state
        end
        unblock(event)
      else
        @result = @received_events.join(',')
        @successful = @state != Relay::CallDetectState::ERROR
      end
    end
  end
end