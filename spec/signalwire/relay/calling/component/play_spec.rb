# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Play do

  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:call) { Signalwire::Relay::Calling::Call.new(client, mock_call_hash.dig(:params, :params, :params)) }
  let(:play_obj) { 'some_play'}

  subject { described_class.new(call: call, play: play_obj, volume: 20) }
  let(:mock_protocol) { "my-protocol" }

  before do
    call.client.protocol = "my-protocol"
  end

  describe "#inner_params" do
    it "has volume if set" do
      expect(subject.inner_params[:volume]).to eq 20
    end
  end

  describe "#stop" do
    it "returns a StopResult" do
      stop_command = nil
      allow(call.client.session).to receive(:transmit) { |arg| stop_command = JSON.parse(arg) }
      async = Thread.new do
        subject.stop
      end
      sleep 0.2
      mock_message call.client.session, relay_response(stop_command['id'])
      expect(async.value).to be_a Signalwire::Relay::Calling::StopResult
      expect(async.value.successful).to eq true
    end
  end

  describe "#volume" do
    it "returns a PlayVolumeResult" do
      volume_command = nil
      allow(call.client.session).to receive(:transmit) { |arg| volume_command = JSON.parse(arg) }
      async = Thread.new do
        subject.volume 30
      end
      sleep 0.2
      mock_message call.client.session, relay_response(volume_command['id'])
      expect(async.value).to be_a Signalwire::Relay::Calling::PlayVolumeResult
      expect(async.value.successful).to eq true
      expect(volume_command.dig('params', 'params', 'volume')).to eq 30
    end
  end


  describe "#execute_subcommand" do
    it "returns a PlayPauseResult" do
      stop_command = nil
      allow(call.client.session).to receive(:transmit) { |arg| stop_command = JSON.parse(arg) }
      async = Thread.new do
        subject.execute_subcommand('.pause', Signalwire::Relay::Calling::PlayPauseResult)
      end
      sleep 0.2
      mock_message call.client.session, relay_response(stop_command['id'])
      expect(async.value).to be_a Signalwire::Relay::Calling::PlayPauseResult
      expect(async.value.successful).to eq true
    end
  end
end