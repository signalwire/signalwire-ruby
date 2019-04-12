# frozen_string_literal: true

require 'spec_helper'

module Signalwire
  RSpec.describe Sdk::Configuration do
    describe '#hostname' do
      it 'there is no default' do
        expect(Sdk::Configuration.new.hostname).to eq nil
      end
    end

    describe '#hostname=' do
      it 'can set value' do
        config = Sdk::Configuration.new
        config.hostname = 'test.signalwire.com'
        expect(config.hostname).to eq('test.signalwire.com')
      end
    end

    describe 'setting up directly in the constructor' do
      it 'sets the configuration in the constructor' do
        client = Signalwire::REST::Client.new 'xyz123-xyz123-xyz123', 'PTxyz123-xyz123-xyz123', signalwire_space_url: 'test.signalwire.com'
        expect(Signalwire::Sdk.configuration.hostname).to eq('test.signalwire.com')
      end
    end
  end
end
