require 'spec_helper'

describe Signalwire::Blade::Provider do
  class self::DummyProvider
    include Signalwire::Blade::Provider

    def process(params: {})
      respond(result: params.to_json)
    end
  end

  subject { self.class::DummyProvider }
  before do
    stub_const('Signalwire::Blade::EnvVars::BLADE_ADDRESS', 'wss://localhost:2100')
  end

  it 'should have public methods' do
    expect(subject).to respond_to(:run)
    expect(subject).to respond_to(:dispatch)
  end

  it 'should not expose private methods' do
    expect { subject.connect }.to raise_error(NoMethodError)
  end

  context 'without providers' do
    it { expect { subject.run }.to raise_error(ArgumentError, /one provider is required/) }
  end

  context 'with valid setup' do
    let!(:mock_connection) { double('Connection', start: nil) }
    let(:params) { { test: 'string' } }

    before :each do
      subject.provides("blade.testservice")
      allow(Signalwire::Blade::Connection).to receive(:new).and_return(mock_connection)
      allow(subject).to receive(:session).and_return(Signalwire::Blade::Session.new)
    end

    it "define the 'session' method on a Provider instance" do
      instance = subject.new('1', 'test')
      subject.run
      expect(instance.class.session).to be_a(Signalwire::Blade::Session)
    end

    it "#dispatch" do
      expect_any_instance_of(subject).to receive(:process).with(params: params).and_call_original
      expect_any_instance_of(subject).to receive(:respond).with(result: '{"test":"string"}')
      subject.dispatch(id: '1', method: 'method', params: params)
    end

    it "on incomingcommand message should trigger #dispatch" do
      expect(subject).to receive(:dispatch).with(id: "testid", method: "blade.testservice", params: { iam: "a test" }).and_call_original
      expect_any_instance_of(subject).to receive(:process).with(params: { iam: "a test" }).and_call_original
      expect_any_instance_of(subject).to receive(:respond).with(result: '{"iam":"a test"}')

      allow(mock_connection).to receive(:start) do
        subject.session.trigger_handler :connected, double("Session")
      end

      subject.run

      req = { id: "testid", method: "blade.testservice", params: { iam: "a test" } }
      subject.session.trigger_handler :incomingcommand, double("Req", **req)
    end
  end
end
