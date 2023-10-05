# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Signalwire::Sdk do
  describe '#configure' do
    it 'returns the configured hostname' do
      Signalwire::Sdk.configure do |config|
        config.hostname = 'demo.signalwire.com'
      end

      twilio_client = Twilio::REST::Client.new
      expect(twilio_client.api.hostname).to eq('demo.signalwire.com')
    end

    it 'requires the hostname configuration to be set' do
      Signalwire::Sdk.configure do |config|
        config.hostname = nil
      end

      expect do
        Twilio::REST::Client.new.api
      end.to raise_exception ArgumentError, /SignalWire Space URL is not configured/
    end
  end
end
