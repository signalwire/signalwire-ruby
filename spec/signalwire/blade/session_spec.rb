# frozen_string_literal: true
require 'spec_helper'

describe Signalwire::Blade::Session do
  subject { described_class.new }
  let(:mock_connection) { double('Connection', start: nil) }
  let(:mock_cache) { double('Cache') }

  before :each do
    stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_PROJECT', 'project')
    stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_TOKEN', 'token')
    allow(Signalwire::Blade::Connection).to receive(:new).and_return(mock_connection)
    allow(Signalwire::Blade::NodeStore).to receive(:new).and_return(mock_cache)
  end

  describe '#start!' do
    after(:each) { subject.start! }

    it 'sets the handlers' do
      expect(subject).to receive(:on).with(:started)
      # Commented because of nodestore handler not working
      #expect(subject).to receive(:on).with(:incomingcommand, method: 'blade.netcast')
    end

    it 'start the connection' do
      expect(mock_connection).to receive(:start)
    end
  end

  describe ':started handler' do
    before(:each) { subject.start! }

    it 'execute a connect request' do
      expect(subject).to receive(:execute).and_call_original
      expect(mock_connection).to receive(:transmit).with(/"blade.connect"/)

      subject.trigger_handler :started, double('Event')
    end
  end

  describe ':incomingcommand netcast handler' do
    before(:each) { subject.start! }

    xit 'update the cache' do
      params = { msg: 'example' }
      expect(mock_cache).to receive(:netcast_update).with(params)

      subject.trigger_handler :incomingcommand, double('Event', method: 'blade.netcast', params: params)
    end
  end

  describe '#execute' do
    let (:command) { Signalwire::Blade::ConnectRequest.new(subject.session_id) }

    it 'should execute and set a callback' do
      expect(mock_connection).to receive(:transmit).with(command.to_json)
      tmp = 'original'
      subject.execute(command) do |event|
        tmp = event.msg
        expect(event.msg).to eq('changed')
      end

      expect(tmp).to eq 'original'
      subject.trigger_handler :result, double('Event', id: command.id, msg: 'changed')
      expect(tmp).to eq 'changed'
    end

    it 'should execute but not set a callback' do
      expect(subject).not_to receive(:once)
      expect(mock_connection).to receive(:transmit).with(command.to_json)

      subject.execute(command)
    end
  end
end
