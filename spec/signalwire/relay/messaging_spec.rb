# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Messaging::Instance do
  subject { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }

  describe '#messaging' do
    it 'is a Messaging::Instance' do
      expect(subject.messaging).to be_a Signalwire::Relay::Messaging::Instance
    end
  end

  describe "message_received" do
    it "broadcasts a :message_received event" do
      received = nil
      subject.messaging.on :message_received do |message|
        received = message
      end

      mock_message subject.session, mock_message_event
      expect(received).to be_a Signalwire::Relay::Messaging::Message
      expect(received.body).to eq "Welcome at SignalWire!"
    end
  end

  describe "message_received" do
    it "broadcasts a :message_received event" do
      received = nil
      subject.messaging.on :message_received do |message|
        received = message
      end

      mock_message subject.session, mock_message_event
      expect(received).to be_a Signalwire::Relay::Messaging::Message
      expect(received.body).to eq "Welcome at SignalWire!"
    end
  end

  describe "message_state_change" do
    it "broadcasts a :message_state_change event" do
      received = nil
      subject.messaging.on :message_state_change do |message|
        received = message
      end

      mock_message subject.session, mock_message_event('state')
      expect(received).to be_a Signalwire::Relay::Messaging::Message
      expect(received.state).to eq "received"
    end
  end

  describe "#send" do
    it "sends the proper payload" do
      expect(subject).to receive(:relay_execute).with({
        method: 'messaging.send',
        protocol: subject.protocol,
        params: {
          body: 'Hello from SignalWire!',
          context: 'outbound',
          from_number: '+1555XXXXXXX',
          to_number: '+1555XXXXXYY'
        }
      })
      subject.messaging.send(from: "+1555XXXXXXX", to: "+1555XXXXXYY", body: "Hello from SignalWire!", context: 'outbound')
    end
  end
end