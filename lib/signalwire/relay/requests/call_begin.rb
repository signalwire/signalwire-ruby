module Signalwire::Relay
  class CallBegin < Signalwire::Blade::Request
    def initialize(protocol:, from_number:, to_number:, timeout: 30, tag: nil)
      @id = new_id
      @protocol = protocol
      @from_number = from_number
      @to_number = to_number
      @timeout = timeout
      @tag = tag
    end
    
    def method
      'blade.execute'
    end

    def params
      {
        "protocol": @protocol,
        "method": "call.begin",
        "params": {
          tag: @tag,
          device: {
            type: 'phone',
            params: {
              from_number: @from_number,
              to_number: @to_number,
              timeout: @timeout
            }
          }
        } 
      }
    end
  end
end