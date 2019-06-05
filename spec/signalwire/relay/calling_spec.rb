# frozen_string_literal: true
require 'spec_helper'

describe Signalwire::Relay::Calling do
  include_context :mock_connection
  subject { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken', signalwire_space_url: 'myspace.signalwire.com') }

  describe "#receive" do
    let(:context) { 'pbx' }
    let(:result_hash) do
      { result: {
        code:'200',
        message: "Receiving inbound calls associated to 'pbx' relay context"
        } 
      }
    end
    let(:call_receive) { Signalwire::Relay::CallReceive.new(subject.protocol, 'pbx') }
    let(:result)  { Signalwire::Blade::Result.new(call_receive.id, result_hash) }

    let(:call_hash) { mock_call_hash }
    let(:incoming_event) { Signalwire::Relay::Event.new(id: SecureRandom.uuid, event_type: 'calling.call.receive', params: call_hash) }

    before do
      allow(Signalwire::Relay::CallReceive).to receive(:new).and_return(call_receive)
    end

    it "sets up the context" do
      subject.calling.receive context: 'pbx'
      trigger_handler_on_session :result, result
      expect(subject.calling.contexts).to eq ['pbx']
    end

    it "triggers and yields a call" do
      subject.calling.receive context: 'pbx' do |call|
        expect(call).to be_a Signalwire::Relay::Call
        expect(subject.calls).to eq([call])
      end
      trigger_handler_on_session :result, result

      subject.broadcast :event, incoming_event
    end
  end

  describe "#new_call" do
    it "creates a Call" do
      expect(subject.new_call(from: '+15552233444', to: '+15556677888')).to be_a Signalwire::Relay::Call
    end
  end
end

# {
#   "jsonrpc": "2.0",
#   "id": "ee1f8c9f-3c8c-4a3e-90a4-7ec35089dd8e",
#   "method": "blade.broadcast",
#   "params": {
#     "broadcaster_nodeid": "3e8e494b-799d-4101-863f-d80efbd54704",
#     "protocol": "signalwire_calling_32898192-e0dd-4794-9a6e-cccf9a8a8f4f_64ae1770-0ce3-43f0-b016-28eb668416bf",
#     "channel": "notifications",
#     "event": "relay",
#     "params": {
#       "event_type": "calling.call.receive",
#       "timestamp": 1556806325.677053,
#       "project_id": "64ae1770-0ce3-43f0-b016-28eb668416bf",
#       "space_id": "f6e0ee46-4bd4-4856-99bb-0f3bc3d3e787",
#       "params": {
#         "call_state": "created",
#         "context": "incoming",
#         "device": {
#           "type": "phone",
#           "params": {
#             "from_number": "+12029085665",
#             "to_number": "12069286532"
#           }
#         },
#         "direction": "inbound",
#         "call_id": "0495a5a7-ce9b-40e8-94ce-67e616c98d1c",
#         "node_id": "f5055cc9-b330-43b1-aa6f-5f970ce651fc"
#       },
#       "event_channel": "signalwire_calling_32898192-e0dd-4794-9a6e-cccf9a8a8f4f_64ae1770-0ce3-43f0-b016-28eb668416bf"
#     }
#   }
# }