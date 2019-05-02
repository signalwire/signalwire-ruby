module Signalwire::Relay
  class Call
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Blade::Logging::HasLogger

    def self.from_event(client, event)
      self.new(client, event)
    end

    def initialize(client, options)
      @client = client
    end
  end
end