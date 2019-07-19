module Signalwire::Relay::Calling
  class FaxReceive < BaseFax
    def method
      Relay::ComponentMethod::RECEIVE_FAX
    end

    def inner_params
      params = {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id
      }
    end 
  end
end