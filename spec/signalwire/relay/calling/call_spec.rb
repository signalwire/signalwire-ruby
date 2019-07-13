# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Call do
  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  subject { described_class.new(client, mock_call_hash.dig(:params, :params, :params)) }

  describe 'connect_state_change' do
    it 'sets the connect state and fires the event' do
      subject.on :call_state_change do |event|
        expect(event).to eq({ previous_state: "created", state: "connected" })
      end

      mock_message subject.client.session, mock_call_state(subject.id)
    end
  end

  describe ".from_event" do  

    let(:incoming_event) { Signalwire::Relay::Event.new(mock_call_hash) }

    it "populates the call properly" do
      call = described_class.from_event(client, incoming_event)
      expect(call.id).to eq incoming_event.call_id
      expect(call.state).to eq 'created'
      expect(call.from).to eq incoming_event.call_params.dig(:device, :params, :from_number)
    end
  end
end
