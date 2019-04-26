# frozen_string_literal: true
require 'spec_helper'

describe Signalwire::Relay::Client do
  it "has a calls accessor" do
    client = Signalwire::Relay::Client.new
    expect(client.calls).to eq({})
  end
end