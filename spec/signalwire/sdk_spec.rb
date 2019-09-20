# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Signalwire::Sdk do
  describe '#configure' do
    it 'returns the configured hostname for signalwire' do
      Signalwire::Sdk.configure do |config|
        config.hostname = 'demo.signalwire.com'
      end

      twilio_client = Twilio::REST::Client.new
      expect(twilio_client.api.hostname).to eq('demo.signalwire.com')
      expect(twilio_client.fax.hostname).to eq('demo.signalwire.com')
      expect(twilio_client.api.service_provider).to eq('signalwire')
    end

    it 'returns the configured hostname for twilio' do
      Signalwire::Sdk.configure do |config|
        # config.hostname = 'demo.signalwire.com'
        config.service_provider = 'twilio'
      end

      twilio_client = Twilio::REST::Client.new
      expect(twilio_client.api.hostname).to eq(nil)
      expect(twilio_client.fax.hostname).to eq(nil)
      expect(twilio_client.api.service_provider).to eq('twilio')
    end


    it 'requires the hostname configuration to be set for signalwire' do
      Signalwire::Sdk.configure do |config|
        config.hostname = nil
      end

      expect do
        Twilio::REST::Client.new.api
      end.to raise_exception ArgumentError, /SignalWire Space URL is not configured/
    end

    it 'does not require the hostname configuration to be set for twilio' do
      Signalwire::Sdk.configure do |config|
        config.hostname = nil
        config.service_provider = 'twilio'
      end

      expect do
        Twilio::REST::Client.new.api
      end.not_to raise_exception ArgumentError, /SignalWire Space URL is not configured/
    end

    after :each do
      Signalwire::Sdk.reset
    end
  end
end
