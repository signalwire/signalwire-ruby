module Signalwire::Relay
  class SubscribeNotificationsRequest < Signalwire::Blade::Request
    def initialize(protocol)
      @id = new_id
      @protocol = protocol
    end
    
    def method
      'blade.subscription'
    end

    def params
      {
        "protocol": @protocol,
        "command": "add",
        "channels": [ "notifications" ]
      }
    end
  end
end