require 'spec_helper'

describe Signalwire::Relay::Calling::Detect do
  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  let(:detect) do
    {
      "type": "machine",
      "params": {
         "initial_timeout": 5.0
      }
    }
  end
  subject { described_class.new(call: call, detect: detect) }

  describe "#execute_params" do
    it "has the correct payload" do
      expect(subject.execute_params).to eq({
        method: subject.method,
        protocol: client.protocol,
        params: {
          call_id: call.id, 
          control_id: subject.control_id,
          detect: detect, 
          node_id:call.node_id, 
          timeout: 30
        }
      })
    end
  end
end