module Signalwire::Relay
  class CallReceive < Signalwire::Blade::Request
    def initialize(protocol, context)
      @id = new_id
      @protocol = protocol
      @context = context
    end
    
    def method
      'blade.execute'
    end

    def params
      {
        "protocol": @protocol,
        "method": "call.receive",
        "params": {
          context: @context
        } 
      }
    end
  end
end