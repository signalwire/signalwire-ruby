require 'spec_helper'

describe Signalwire::Relay::Messaging::Message do
  subject { described_class.new(from_number: '+1555XXXXXXX', to_number: '+1555YYYYYYY', context: 'incoming', body: "hello from SignalWire") }

  describe "#send_request" do
    it "has the correct payload" do
      expect(subject.send_request('protocol123')).to eq "foo"
    end
  end
end