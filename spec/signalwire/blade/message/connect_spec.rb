# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::Connect do
  subject { described_class.new }
  it 'has an ID' do
    expect(subject.id).to_not be nil
  end

  it 'serializes to JSON' do
    connect = described_class.new.build_request
    expect(connect.dig(:params, :version)).to eq(major: 2, minor: 1, revision: 0)
  end
end
