# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Component do
  class SpecComponent < described_class
    def method
      'spec_method'
    end

    def payload
      {
        some: 'payload'
      }
    end

    def event_type
      Relay::CallNotification::STATE
    end

    def notification_handler(event)
        if event.call_params[:call_state] == Relay::CallState::ANSWERED
        @event = event
        unblock(event)
      end
    end
  end

  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  subject { SpecComponent.new(call: call) }
  let(:mock_protocol) { "my-protocol" }

  before do
    call.client.protocol = "my-protocol"
  end

  describe "#initialize" do
    it "is added to the Call" do
      expect(call.components).to eq([subject])
    end
  end

  describe "#execute_params" do
    it "merges all values correctly" do
      expect(subject.execute_params).to eq({
        method: subject.method,
        protocol: mock_protocol,
        params: {
          call_id: call.id,
          node_id: call.node_id,
          params: subject.payload
        }
      })
    end
  end

  describe "#wait_for" do
    it "waits for one of the specified events" do
      allow(subject).to receive(:execute)
      async = Thread.new do
        subject.setup_handlers
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