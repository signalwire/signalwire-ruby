# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Event do
  let(:message) do
    {
      params: {
        params: {
          event_type: 'myevent',
          params: {
            control_id: 'myid'
          }
        }
      }
    }
  end

  subject { described_class.new(message) }

  it 'has shortcut accessors' do
    expect(subject.event_type).to eq 'myevent'
    expect(subject.control_id).to eq 'myid'
    expect(subject.call_id).to eq nil
  end

  describe '.from_blade' do
    let(:blade_message) { Signalwire::Blade::Message.new(message) }
    let(:event) { Signalwire::Relay::Event.from_blade(blade_message) }

    it 'creates a Relay Event' do
      expect(event).to be_a described_class
    end
  end
end
