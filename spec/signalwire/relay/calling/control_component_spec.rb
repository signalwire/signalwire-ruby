# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::ControlComponent do
  class ControlSpecComponent < Signalwire::Relay::Calling::ControlComponent
    def method
      'spec_method'
    end

    def payload
      {
        some: 'payload'
      }
    end

    def event_type
      Relay::CallNotification::PLAY
    end

    def notification_handler(event)
      if @events_waiting.include?(event.call_params[:state])
        @event = event
        unblock(event)
      end
    end
  end

  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  subject { ControlSpecComponent.new(call: call) }
  let(:mock_protocol) { "my-protocol" }

  before do
    call.client.protocol = "my-protocol"
  end

  describe "#execute_params" do
    it "merges all values correctly" do
      expect(subject.execute_params).to eq({
        method: subject.method,
        protocol: mock_protocol,
        params: {
          callid: call.id,
          nodeid: call.node_id,
          control_id: subject.control_id,
          params: subject.payload
        }
      })
    end
  end

  describe "#setup_waiting_events" do
    it "waits for one of the specified events" do
      subject.setup_handlers
      async = Thread.new do
        subject.setup_waiting_events(Relay::CallPlayState::FINISHED)
        :ended
      end
      sleep 0.2
      mock_message call.client.session, mock_component_event(call.id, subject.control_id, Relay::CallNotification::PLAY, 'state', Relay::CallPlayState::FINISHED)
      expect(async.value).to eq :ended
      expect(subject.event.event_type).to eq Relay::CallNotification::PLAY
    end
  end
end