require 'spec_helper'

describe Signalwire::Relay::Calling::PlayMediaAction do
  let(:call) { double('Call', client: double('Client', node_id: 'my_node'), id: 'my_call' ) }
  let(:control_id) { 'my_ctrl'}

  subject{ described_class.new(call: call, control_id: control_id) }

  it 'has the correct properties' do
    expect(subject.control_id).to eq control_id
  end

  describe "#stop" do
    it "sends the stop with the approriate payload" do
      expect(call).to receive(:execute_call_command).with("call.play.stop", { call_id: call.id, control_id: control_id, node_id: call.client.node_id} )
      subject.stop
    end
  end
end