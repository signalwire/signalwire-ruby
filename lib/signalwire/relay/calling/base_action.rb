module Signalwire::Relay::Calling
  class BaseAction
    attr_reader :base_method, :call, :control_id

    def initialize(call:, control_id:)
      @call = call
      @control_id = control_id
    end

    def stop
      params = {
        node_id: @call.client.node_id,
        call_id: @call.id,
        control_id: @control_id
      }

     @call.execute_call_command("#{base_method}.stop", params)
    end
  end
end