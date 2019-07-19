# frozen_string_literal: true

module Signalwire::Relay
  class Event < Signalwire::Blade::Message
    def event_type
      dig(:params, :params, :event_type)
    end

    def name
      event_type
    end

    def call_id
      dig(:params, :params, :params, :call_id)
    rescue StandardError
      nil
    end

    def control_id
      dig(:params, :params, :params, :control_id)
    rescue StandardError
      nil
    end

    def event_params
      dig(:params, :params)
    rescue StandardError
      {}
    end

    def call_params
      dig(:params, :params, :params)
    rescue StandardError
      {}
    end

    def message
      event_params[:message]
    end

    def self.from_blade(blade_event)
      new(blade_event.payload)
    end
  end
end
