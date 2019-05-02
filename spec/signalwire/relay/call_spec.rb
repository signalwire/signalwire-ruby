require 'spec_helper'

describe Signalwire::Relay::Call do
  describe ".from_event" do
    
    let(:call_hash) do 
      { 
        event_type: "calling.call.receive",
        timestamp: 1556806325.677053,
        project_id: "myproject123",
        space_id: "myspace345",
        params: {
          call_state: "created",
          context: "incoming",
          device: {
              type: "phone",
              params: {
                from_number: "+15556667778",
                to_number: "+15559997777"
              }
            },
          direction: "inbound",
          call_id: "0495a5a7-ce9b-40e8-94ce-67e616c98d1c",
          node_id: "some-node-id" 
        }
      } 
    end

    let(:incoming_event) { Signalwire::Relay::Event.new(id: SecureRandom.uuid, event_type: 'calling.call.receive', params: call_hash) }

    it "populates the call properly" do
      call = described_class.from_event(double('Client'), incoming_event)
      expect(call.id).to eq call_hash[:call_id]
      expect(call.from).to eq call_hash[:params][:device][:params][:from]
    end
  end
end