# frozen_string_literal: true
require 'spec_helper'

describe Signalwire::Relay::Client do
  include_context :mock_connection
  subject { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken', signalwire_space_url: 'myspace.signalwire.com') }

  it "has a calls accessor" do
    expect(subject.calls).to eq({})
  end

  describe "#clean_up_space_url" do
    it "should add a protocol and suffix if not present" do
      expect(subject.clean_up_space_url('my.signalwire.com')).to eq 'wss://my.signalwire.com:443/api/relay/wss'
    end

    it "leaves a specified URL alone" do
      expect(subject.clean_up_space_url('wss://my.someurl.com:8888/path')).to eq 'wss://my.someurl.com:8888/path'
    end
  end

  describe "#connect!" do
    it "sets up the client" do
      subject.connect!
    end
  end

  describe "event handling" do
    it "triggers the :event handler on an :incomingcommand with the right payload" do
      event = Signalwire::Blade::IncomingCommand.new(SecureRandom.uuid, 'blade.broadcast', { params: { event: 'relay', foo: 123 } } )

      subject.on :event do |evt|
        expect(trigger).to be_a Signalwire::Relay::Event
        expect(trigger.params[:foo]).to eq 123
      end

      trigger_handler_on_session :incomingcommand, event
    end
  end

  describe "#relay_execute" do
    let(:status) { '200' }
    let(:result_hash) do
      { result: {
        code: status,
        message: "Receiving inbound calls associated to 'incoming' relay context"
        } 
      }
    end
    let(:call_receive) { Signalwire::Relay::CallReceive.new(subject.protocol, 'incoming') }
    let(:result)  { Signalwire::Blade::Result.new(call_receive.id, result_hash) }

    it "calls the passed block on a 200" do
      subject.relay_execute(call_receive)
      trigger_handler_on_session :result, result
    end
  end
end

# {
#   "jsonrpc": "2.0",
#   "id": "d25c2540-a18a-4b4e-aa69-058bea6e5127",
#   "result": {
#     "requester_nodeid": "e516f275-c0da-481f-8c66-3517b9c0fd3c",
#     "responder_nodeid": "3e8e494b-799d-4101-863f-d80efbd54704",
#     "result": {
#       "code": "200",
#       "message": "Receiving inbound calls associated to 'incoming' relay context"
#     }
#   }
# }