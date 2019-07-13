require 'spec_helper'

describe Signalwire::Relay::Calling::Dial do
  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  subject { described_class.new(call: call) }

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
          tag: call.tag,
          device: call.device
        }
      })
    end
  end
end