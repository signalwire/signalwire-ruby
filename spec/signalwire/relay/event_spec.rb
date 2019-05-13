require 'spec_helper'

describe Signalwire::Relay::Event do
  describe ".from_blade" do
    let(:call_params) do 
      {
        call_state: "created",
        context: "incoming",
        device: {
          type: "phone",
          params: {
            from_number: "+12029085665",
            to_number: "12069286532"
          }
        }
      }
      end

    let(:blade_command) {
      Signalwire::Blade::IncomingCommand.new(SecureRandom.uuid, 'blade.broadcast', { params: { event_type: "calling.call.receive", params: call_params } })
    }

    it "returns a correctly populated event" do
      result = described_class.from_blade(blade_command)

      expect(result).to be_a described_class
      expect(result.id).to eq blade_command.id
      expect(result.event_type).to eq "calling.call.receive"
    end
  end
end