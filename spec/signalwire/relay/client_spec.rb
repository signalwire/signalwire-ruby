# frozen_string_literal: true
require 'spec_helper'

describe Signalwire::Relay::Client do
  include_context :mock_connection
  subject { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken', signalwire_space_url: 'myspace.signalwire.com') }

  it "has a calls accessor" do
    expect(subject.calls).to eq({})
  end

  describe "#clean_up_space_url" do
    it "should add a protocol and suffix if not present" do
      expect(subject.clean_up_space_url('my.signalwire.com')).to eq 'wss://my.signalwire.com:443/api/relay/wss'
    end

    it "leaves a specified URL alone" do
      expect(subject.clean_up_space_url('wss://my.someurl.com:8888/path')).to eq 'wss://my.someurl.com:8888/path'
    end
  end

  describe "#connect!" do
    it "setup up the client" do
      subject.connect!
    end
  end
end