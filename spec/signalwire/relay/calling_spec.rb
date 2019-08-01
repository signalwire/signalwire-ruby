# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Instance do
  subject { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }

  describe '#calling' do
    it 'is a Calling::Instance' do
      expect(subject.calling).to be_a Signalwire::Relay::Calling::Instance
    end
  end

  describe '#receive' do
    let(:context) { 'pbx' }

    it 'sets up the context and yields a call' do
      receive_command = nil
      allow(subject.session).to receive(:transmit) { |arg| receive_command = JSON.parse(arg) }

      Thread.new do
        subject.calling.receive context: 'pbx'
      end
      sleep 0.1

      mock_message subject.session, relay_response(receive_command['id'])

      call = nil
      mock_message subject.session, mock_call_hash
    end
  end

  describe 'call event handling' do
    let(:incoming_event) { Signalwire::Relay::Event.new(mock_call_hash) }
    let(:call) { Signalwire::Relay::Calling::Call.new(subject, incoming_event.call_params) }

    before do
      subject.calling.calls << call
    end

    it "removes the call on ended" do
      mock_message subject.session, mock_call_state(call.id, Relay::CallState::ENDED)
      expect(subject.calling.calls).to eq([])
    end
  end

  describe '#find_call_by_tag' do
    it 'finds the call' do
      created_call = subject.calling.new_call(from: '+15552233444', to: '+15556677888')
      expect(subject.calling.find_call_by_tag(created_call.tag)).to eq created_call
    end
  end
end
