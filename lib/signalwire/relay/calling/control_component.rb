# frozen_string_literal: true

require 'securerandom'

module Signalwire::Relay::Calling
  class ControlComponent < Component
    def control_id
      @control_id ||= SecureRandom.uuid
    end

    def inner_params
      {
        nodeid: @call.node_id,
        callid: @call.id,
        control_id: control_id,
        params: payload
      }
    end

    def setup_handlers
      @call.on :event, event_type: event_type, control_id: control_id do |evt|
        notification_handler(evt)
      end
    end

    def stop
      @call.relay_execute execute_params('.stop') do |event, outcome|
        if outcome == :failure
          terminate(event)
          return event
        end
      end
    end
  end
end
