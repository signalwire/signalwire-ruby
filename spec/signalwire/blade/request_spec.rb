# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::Request do
  describe 'execute' do
    let(:mock_connection) { double('Connection')}
    let(:command) { described_class.new('foo') }

    it 'sets and executes handlers' do
      expect(Signalwire::Blade::Connection).to receive(:new).and_return(mock_connection)
      expect(mock_connection).to receive(:transmit).with(command.to_json)
      session = Signalwire::Blade::Session.new

      a = 1
      session.execute(command) do |event|
        a = event.new_value
      end

      event = double('Event', id: command.id, new_value: 'abc')
      session.trigger_handler :result, event

      expect(a).to eq 'abc'
    end
  end
end
