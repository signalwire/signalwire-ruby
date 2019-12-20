# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::Ping do

  subject { described_class.new }

  it 'generates the correct request' do
    expect(subject.build_request).to eq(id: subject.id, jsonrpc: '2.0', method: 'blade.ping',
      params: {} )
  end
end
