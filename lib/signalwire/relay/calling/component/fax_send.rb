module Signalwire::Relay::Calling
  class FaxSend < BaseFax
    def initialize(call:, document:, identity: nil, header: nil)
      super(call: call)
      @priv_document = document
      @priv_identity = identity
      @priv_header = header
    end

    def method
      Relay::ComponentMethod::SEND_FAX
    end

    def inner_params
      params = {
        node_id: @call.node_id,
        call_id: @call.id,
        control_id: control_id,
        document: @priv_document
      }

      params[:identity] = @priv_identity if @priv_identity
      params[:header_info] = @priv_header if @priv_header

      params
    end 
  end
end