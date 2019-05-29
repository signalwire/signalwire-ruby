module Signalwire::Relay
  class Event
    attr_accessor :id, :event_type, :params

    def self.from_blade(blade_event)
      self.new(id: blade_event.id, event_type: blade_event.params[:params][:event_type], params: blade_event.params)
    end
    
    def initialize(id:, event_type:, params:)
      @id = id
      @event_type = event_type
      @params = params
    end

    def call_id
      params[:params][:params][:call_id] rescue nil
    end
  end
end