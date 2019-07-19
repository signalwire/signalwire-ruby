require 'spec_helper'

describe Signalwire::Relay::Task do
  let(:project) { '64ae1770-0ce3-43f0-b016-28eb668416bf' }
  let(:token)   { 'PTdfc2140fa0a6e1b1c7538a89123d983f681817fcd343e9d2' }

  let(:context) { 'task_context' }
  let(:message) { { some: 'action' } }

  subject { described_class.new(project: project, token: token) }

  describe "#deliver" do
    it "sends the correct request" do
      VCR.use_cassette('task_deliver') do
        expect(subject.deliver(context: context, message: message)).to eq true
      end
    end
  end
end