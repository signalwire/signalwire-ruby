# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::AuthorityRequest do
  subject { described_class.new }

  it 'serializes to a Blade command' do
    expect(subject.to_json).to eq "{\"jsonrpc\":\"2.0\",\"id\":\"#{subject.id}\",\"method\":\"blade.authority\",\"params\":{\"command\":\"add\"}}"
  end
end
