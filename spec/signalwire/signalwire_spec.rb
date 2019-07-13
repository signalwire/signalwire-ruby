# frozen_string_literal: true

require 'spec_helper'

describe Signalwire do
  it 'returns a Version' do
    expect(Signalwire::VERSION).to eq '2.0.0'
  end
end
