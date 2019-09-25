# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Record do

  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  subject { described_class.new(call: call, record: {}) }
  let(:mock_protocol) { "my-protocol" }

  let(:mock_record_event) do
    Signalwire::Relay::Event.new({
      params: { params: { params: {
        url: 'foo.mp3'
      }}}
    })
  end

  before do
    call.client.protocol = "my-protocol"
  end

  describe "url" do
    it "sets the url on reply" do
      subject.handle_execute_result(mock_record_event, :success)
      expect(subject.url).to eq 'foo.mp3'
    end
  end
end