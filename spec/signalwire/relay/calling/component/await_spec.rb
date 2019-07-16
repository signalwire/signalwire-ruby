# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Await do

  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  subject { described_class.new(call: call) }
  let(:mock_protocol) { "my-protocol" }

  before do
    call.client.protocol = "my-protocol"
  end

  describe "#initialize" do
    it "is added to the Call" do
      expect(call.components).to eq([subject])
    end
  end

  describe "#wait_for" do
    it "waits for one of the specified events" do
      async = Thread.new do
        subject.wait_for(Relay::CallState::ANSWERED)
        :called
      end
      sleep 0.2

      mock_message call.client.session, mock_call_state(call.id, Relay::CallState::ANSWERED)
      expect(async.value).to eq :called
      expect(subject.event.event_type).to eq Relay::CallNotification::STATE
    end
  end
end