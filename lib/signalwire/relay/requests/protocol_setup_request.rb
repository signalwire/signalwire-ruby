module Signalwire::Relay
  class ProtocolSetupRequest < Signalwire::Blade::Request
    def initialize
      @id = new_id
    end
    
    def method
      'blade.execute'
    end

    def params
      {
        "protocol": "signalwire",
        "method": "setup",
        "params": {
            "service": "calling"
        }
      }
    end
  end
end