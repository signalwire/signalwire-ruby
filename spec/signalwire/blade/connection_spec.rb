# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::Connection do
  subject { described_class.new }

  describe 'flush_queues' do
    it 'flushes events in order' do
      allow(subject).to receive(:connected?).and_return(true)
      expect(subject).to receive(:write).with(:foo).once.ordered
      expect(subject).to receive(:write).with(:bar).once.ordered

      EM.run do
        subject.transmit :foo
        subject.transmit :bar

        subject.flush_queues

        EM.stop
      end
    end
  end
end
