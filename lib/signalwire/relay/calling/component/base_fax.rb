# frozen_string_literal: true

module Signalwire::Relay::Calling
  class BaseFax < ControlComponent
    attr_reader :direction, :identity, :remote_identity, :document, :pages

    def event_type
      Relay::CallNotification::FAX
    end

    def notification_handler(event)
      fax_state = event.call_params[:fax]
      fax_params = fax_state[:params]
      @state = fax_state[:type]

      @completed = @state != Relay::CallFaxState::PAGE

      if @completed
        if fax_params[:success]
          @successful = true
          @direction = fax_params[:direction]
          @identity = fax_params[:identity]
          @remote_identity = fax_params[:remote_identity]
          @document = fax_params[:document]
          @pages = fax_params[:pages]
        end

        @event = event
      end

      broadcast_event(event)
      check_for_waiting_events
    end

    def broadcast_event(event)
      @call.broadcast "fax_#{@state}".to_sym, event
      @call.broadcast :fax_state_change, event
    end
  end
end
