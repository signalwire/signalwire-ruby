# frozen_string_literal: true

module Signalwire::Relay::Calling
  class Record < ControlComponent
    attr_reader :url, :duration, :size
    def initialize(call:, record:)
      super(call: call)
      @record = record
    end

    def method
      Relay::ComponentMethod::RECORD
    end

    def event_type
      Relay::CallNotification::RECORD
    end

    def inner_params
      {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        record: @record
      }
    end

    def notification_handler(event)
      @state = event.call_params[:state]
      url = event.call_params[:url]
      duration = event.call_params[:duration]
      size = event.call_params[:size]

      @completed = @state != Relay::CallRecordState::RECORDING

      if @completed
        @successful = @state == Relay::CallRecordState::FINISHED
        @url = url
        @duration = duration
        @size = size
        @event = event
      end

      broadcast_event(event)
      check_for_waiting_events
    end

    def broadcast_event(event)
      @call.broadcast "record_#{@state}".to_sym, event
      @call.broadcast :record_state_change, event
    end

    def after_execute(execute_event)
      @url = execute_event.call_params[:url]
    end
  end
end
