module Signalwire::Relay
  class Call
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Blade::Logging::HasLogger

    def initialize(client, **options)
      @client = client
    end


  end
end