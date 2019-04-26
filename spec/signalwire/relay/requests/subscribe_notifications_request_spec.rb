require 'spec_helper'

describe Signalwire::Relay::SubscribeNotificationsRequest do
  let(:protocol) { 'myproto' }

  subject { described_class.new(protocol) }

  it 'renders in JSON correctly' do
    result = JSON.parse(subject.to_json)
    expect(result['params']['protocol']).to eq protocol
  end
end