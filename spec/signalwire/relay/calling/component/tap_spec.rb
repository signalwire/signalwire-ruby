require 'spec_helper'

describe Signalwire::Relay::Calling::Tap do
  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  let(:tap) do
    { type: 'audio', params: { direction: 'listen' } }
  end
  let(:device) do
    { type: 'rtp', params: { addr: '127.0.0.1' } }
  end
  subject { described_class.new(call: call, tap: tap, device: device  ) }

  let(:mock_protocol) { "my-protocol" }

  before do
    call.client.protocol = "my-protocol"
  end

  describe "#execute_params" do
    it "merges all values correctly" do
      expect(subject.execute_params).to eq({
        method: subject.method,
        protocol: mock_protocol,
        params: {
          call_id: call.id,
          control_id: subject.control_id,
          node_id: call.node_id,
          device: device,
          tap: tap
        }
      })
    end
  end
end