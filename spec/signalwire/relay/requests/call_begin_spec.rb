require 'spec_helper'

describe Signalwire::Relay::CallBegin do
  let(:protocol) { 'myproto' }
  let(:from_number) { '+155512312345' }

  subject { described_class.new(protocol: protocol, from_number: from_number, to_number: '+155512312349') }

  it 'renders in JSON correctly' do
    result = JSON.parse(subject.to_json)
    expect(result['params']['protocol']).to eq protocol
    expect(result['params']['params']['device']['params']['from_number']).to eq from_number
  end
end