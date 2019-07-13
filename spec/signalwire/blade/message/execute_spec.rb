# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::Execute do
  let(:params) do
    { one: 'two', foo: { bar: 'baz' } }
  end

  subject { described_class.new(params) }

  it 'generates the correct request' do
    expect(subject.build_request).to eq(id: subject.id, jsonrpc: '2.0', method: 'blade.execute',
      params: { foo: { bar: 'baz' }, one: 'two' })
  end
end
