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
  end
end
