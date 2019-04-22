require 'spec_helper'

describe Signalwire::Blade::Provider::Authority do
  class self::DummyProvider
    include Signalwire::Blade::Provider
    provides "test.test"
  end

  subject { self.class::DummyProvider }
  before { ENV['BLADE_ADDRESS'] = "wss://localhost:2100" }

  describe '#start' do
    let(:mock_connection) { double('Connection', start: nil) }
    let(:authority_request) { Signalwire::Blade::AuthorityRequest.new }

    def mock_authority_result # Helper method
      described_class.start(subject)
      subject.session.trigger_handler :result, double('AR', id: authority_request.id)
    end

    before :each do
      allow(Signalwire::Blade::Connection).to receive(:new).and_return(mock_connection)
      allow(subject).to receive(:session).and_return(Signalwire::Blade::Session.new)
      allow(Signalwire::Blade::AuthorityRequest).to receive(:new).and_return(authority_request)

      expect(mock_connection).to receive(:transmit).with(authority_request.to_json)

      subject.run
    end

    it 'register an handler for authenticate requests' do
      expect_any_instance_of(Signalwire::Blade::Session).to receive(:on).with(:incomingcommand, method: "blade.authenticate")
      mock_authority_result
    end

    it 'dispatch the Provider when an authenticate comes in' do
      req = { id: "testid", method: "blade.authenticate", params: { iam: "a test" } }
      expect(subject).to receive(:dispatch).with(req)
      mock_authority_result

      subject.session.trigger_handler :incomingcommand, double("authenticate_request", **req)
    end
  end
end
