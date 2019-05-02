require 'spec_helper'

describe Signalwire::Relay::CallExecute do
  let(:protocol) { 'myproto' }
  let(:method) { 'call.answer' }
  let(:params) { { node_id: '1234', call_id: '4567' } }

  subject { described_class.new(protocol: protocol, method: method, params: params) }

  it 'renders in JSON correctly' do
    result = JSON.parse(subject.to_json)
    expect(result['params']['protocol']).to eq protocol
    expect(result['params']['protocol']).to eq protocol
    expect(result['params']['params']).to eq JSON.parse(params.to_json)
  end
end