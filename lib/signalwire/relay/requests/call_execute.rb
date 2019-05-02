module Signalwire::Relay
  class CallExecute < Signalwire::Blade::Request
    def initialize(protocol:, method:, params:)
      @id = new_id
      @protocol = protocol
      @relay_method = method
      @relay_params = params
    end
    
    def method
      'blade.execute'
    end

    def params
      {
        protocol: @protocol,
        method: @relay_method,
        params: @relay_params
      }
    end
  end
end