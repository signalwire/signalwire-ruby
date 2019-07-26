require 'spec_helper'

describe Signalwire::Relay::Messaging::Message do

  let(:event) { Signalwire::Relay::Event.new(mock_message_event) }
  subject { described_class.new(event.payload) }

  describe "accessors" do
    it "has various accessors" do
      described_class::FIELDS.each do |meth|
        expect(subject.send(meth)).to eq event.dig(:params, :params, :params, meth)
        expect(subject.body).to eq "Welcome at SignalWire!"
      end
    end
  end
end