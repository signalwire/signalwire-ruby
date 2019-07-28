require 'spec_helper'

describe Signalwire::Relay::Messaging::Message do

  let(:event) { Signalwire::Relay::Event.new(mock_message_event) }
  subject { described_class.new(event.payload) }

  describe "accessors" do
    it "has various accessors" do
      described_class::FIELDS.each do |meth|
        # expect(subject.send(meth)).to eq event.dig(:params, :params, :params, meth)
        expect(subject.body).to eq "Welcome at SignalWire!"
        expect(subject.from).to eq event.dig(:params, :params, :params, :from_number)
        expect(subject.to).to eq event.dig(:params, :params, :params, :to_number)
        expect(subject.state).to eq event.dig(:params, :params, :params, :message_state)
        expect(subject.id).to eq event.dig(:params, :params, :params, :message_id)
      end
    end
  end
end