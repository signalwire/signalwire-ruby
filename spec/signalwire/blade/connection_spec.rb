# frozen_string_literal: true
require 'spec_helper'

describe Signalwire::Blade::Connection do
  let(:session) { Signalwire::Blade::Session.new }
  subject { described_class.new(session) }
  # let(:mock_connect) { double('Connect') }
  # let(:mock_cache) { double('Cache') }

  before :each do
    stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_PROJECT', 'project')
    stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_TOKEN', 'token')
    allow(subject).to receive(:connect).and_return(nil)
    allow(subject).to receive(:event_loop).and_return(nil)
    # allow(Signalwire::Blade::NodeStore).to receive(:new).and_return(mock_cache)
  end

  describe '#start' do
    # after(:each) { subject.start! }

    it 'sets the handlers' do
      expect(subject).to receive(:connect)
      expect(subject).to receive(:event_loop)

      subject.start
    end
  end

  describe '#close' do
    it 'restore the connection if not shutdown' do
      subject.start
      expect(subject).to receive(:connect)
      subject.close
    end
  end

  describe '#shutdown' do

  end
end
