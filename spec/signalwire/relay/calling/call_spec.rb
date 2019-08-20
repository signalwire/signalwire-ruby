# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Call do
  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  subject { described_class.new(client, mock_call_hash.dig(:params, :params, :params)) }

  describe 'call_state_change' do
    it 'sets the call state and fires the event' do
      subject.on :call_state_change do |event|
        expect(event).to eq({ previous_state: "created", state: "answered" })
      end

      mock_message subject.client.session, mock_call_state(subject.id)
    end
  end

  describe 'connect_state_change' do
    let(:peered_call){ described_class.new(client, mock_call_hash('created', 'some-call-id').dig(:params, :params, :params)) }

    before do
      client.calling.calls << peered_call
    end

    it 'sets the peer and fires the event' do
      subject.on :connect_state_change do |event|
        expect(event).to eq({ previous_state: nil, state: "connected" })
      end

      mock_message subject.client.session, mock_connect_state(subject.id, peered_call.id)
      expect(subject.peer).to be peered_call
    end
  end

  describe 'ending a call' do
    it 'sets the busy state' do
      message = mock_call_state(subject.id, Relay::CallState::ENDED)
      message[:params][:params][:reason] = Relay::DisconnectReason::BUSY
      mock_message subject.client.session, message

      expect(subject.busy).to eq true
    end
  end

  describe ".from_event" do  

    let(:incoming_event) { Signalwire::Relay::Event.new(mock_call_hash) }

    it "populates the call properly" do
      call = described_class.from_event(client, incoming_event)
      expect(call.id).to eq incoming_event.call_id
      expect(call.state).to eq 'created'
      expect(call.from).to eq incoming_event.call_params.dig(:device, :params, :from_number)
    end
  end

  describe "#wait_for" do
    it "returns true without blocking if we are already past the state" do
      mock_message subject.client.session, mock_call_state(subject.id, Relay::CallState::ENDING)
      expect(Signalwire::Relay::Calling::Await).to receive(:new).never
      expect(subject.wait_for(Relay::CallState::RINGING)).to eq true
    end

    it "blocks and waits for the event" do
      result = Thread.new do
        subject.wait_for(Relay::CallState::RINGING, Relay::CallState::ANSWERED)
      end
      sleep 0.2

      mock_message subject.client.session, mock_call_state(subject.id, Relay::CallState::ANSWERED)
      expect(result.value).to eq true
    end
  end

  describe "#prompt" do
    let(:collect_obj) { 'some_collect'}
    let(:play_obj) { 'some_play'}
    let(:prompt_double) { double('Prompt', wait_for: nil) }

    context "with valid parameters" do
      before do
        expect(Signalwire::Relay::Calling::Prompt).to receive(:new).with(call: subject, collect: collect_obj, play: play_obj).and_return(prompt_double)
      end

      it "handles positional parameters" do
        subject.prompt(collect_obj, play_obj)
      end

      it "handles keyword parameters" do
        subject.prompt(collect: collect_obj, play: play_obj)
      end

      it "handles mixed parameters" do
        subject.prompt(collect_obj, play: play_obj)
      end
    end

    it "raises on a missing parameter" do
      expect {
        subject.prompt(collect_obj)
      }.to raise_error(ArgumentError)
    end
  end
end
