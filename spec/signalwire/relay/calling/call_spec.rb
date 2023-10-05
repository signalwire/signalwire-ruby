# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Calling::Call do
  let(:client) { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }
  let(:collect_obj) { { "initial_timeout": 10.0, "digits": { "max": 1, "digit_timeout": 5.0 } } }

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
    let(:play_obj) { 'some_play'}
    let(:prompt_double) { double('Prompt', wait_for: nil) }

    context "with valid parameters" do
      before do
        expect(Signalwire::Relay::Calling::Prompt).to receive(:new).with(call: subject, collect: collect_obj, play: play_obj, volume: nil).and_return(prompt_double)
      end

      it "handles positional parameters" do
        subject.prompt(collect_obj, play_obj)
      end

      it "handles keyword parameters" do
        subject.prompt(collect: collect_obj, play: play_obj)
      end

      it "handles keyword single parameters" do
        subject.prompt(initial_timeout: 10.0, digits_max: 1, digits_timeout: 5.0, play: play_obj)
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

    it "raises on a missing parameter with keywords" do
      expect {
        subject.prompt(collect: collect_obj)
      }.to raise_error(ArgumentError)
    end
  end

  describe "#connect" do
    let(:devices_obj) { 'some_devices'}
    let(:ringback_obj) { 'some_ringback'}
    let(:connect_double) { double('Conenct', wait_for: nil) }

    context "with valid parameters" do
      before do
        expect(Signalwire::Relay::Calling::Connect).to receive(:new).with(call: subject, devices: devices_obj).and_return(connect_double)
      end

      it "handles positional parameters" do
        subject.connect(devices_obj)
      end

      it "handles keyword parameters" do
        subject.connect(devices: devices_obj)
      end
    end

    context "with a ringback parameter" do
      before do
        expect(Signalwire::Relay::Calling::Connect).to receive(:new).with(call: subject, devices: devices_obj, ringback: ringback_obj).and_return(connect_double)
      end

      it "handles positional parameters" do
        subject.connect(devices_obj, ringback_obj)
      end

      it "handles keyword parameters" do
        subject.connect(devices: devices_obj, ringback: ringback_obj)
      end
    end
  end

  describe "#prompt_tts" do
    let(:sentence_obj) { 'some_sentence'}
    let(:language) { "en-US" }
    let(:play_obj) do
       [{ params: {gender: "female", language: language, text: sentence_obj}, type: "tts" }]
    end
    let(:prompt_double) { double('Prompt', wait_for: nil) }

    context "with valid parameters" do
      before do
        expect(Signalwire::Relay::Calling::Prompt).to receive(:new).with(call: subject, collect: collect_obj, play: play_obj, volume: nil).and_return(prompt_double)
      end

      it "handles positional parameters" do
        subject.prompt_tts(collect_obj, sentence_obj)
      end

      it "handles keyword parameters" do
        subject.prompt_tts(collect: collect_obj, text: sentence_obj)
      end

      it "handles keyword single parameters" do
        subject.prompt_tts(initial_timeout: 10.0, digits_max: 1, digits_timeout: 5.0, text: sentence_obj)
      end

      context "optional parameters" do
        let(:language) { "it-IT" }
        it "handles optional parameters" do
          subject.prompt_tts(collect: collect_obj, text: sentence_obj, language: language)
        end
      end
    end
  end

  describe "#prompt_ringtone" do
    let(:tone_name) { "us" }
    let(:prompt_double) { double('Prompt', wait_for: nil) }
    let(:play_obj) do
      [{params: {name: "us"}, type: "ringtone"}]
    end

    context "with valid parameters" do
      before do
        expect(Signalwire::Relay::Calling::Prompt).to receive(:new).with(call: subject, collect: collect_obj, play: play_obj, volume: nil).and_return(prompt_double)
      end

      it "handles keyword single parameters" do
        subject.prompt_ringtone(initial_timeout: 10.0, digits_max: 1, digits_timeout: 5.0, name: tone_name)
      end
    end
  end

  describe "#play_tts" do
    let(:sentence_obj) { 'some_sentence'}
    let(:language) { "en-US" }
    let(:play_obj) do
        [{ params: {gender: "female", language: language, text: sentence_obj}, type: "tts" }]
    end
    let(:play_double) { double('Play', wait_for: nil) }

    context "with valid parameters" do
      before do
        expect(Signalwire::Relay::Calling::Play).to receive(:new).with(call: subject, play: play_obj, volume: nil).and_return(play_double)
      end

      it "handles positional parameters" do
        subject.play_tts(sentence_obj)
      end

      it "handles keyword parameters" do
        subject.play_tts(text: sentence_obj)
      end

      context "optional parameters" do
        let(:language) { "it-IT" }
        it "handles optional parameters" do
          subject.play_tts(text: sentence_obj, language: language)
        end
      end
    end
  end

  describe "#detect" do
    let(:detect_obj) do
        { type: :digit, params: { digits: '123' } }
    end
    let(:detect_double) { double('Detect', wait_for: nil) }
    let(:timeout) { 20 }

    before do
      expect(Signalwire::Relay::Calling::Detect).to receive(:new).with(call: subject, detect: detect_obj, timeout: timeout, wait_for_beep: nil).and_return(detect_double)
    end

    context "with digits" do
      it "handles parameters" do
        subject.detect(type: :digit, digits: '123', timeout: timeout)
      end
    end

    context "with fax" do
      let(:detect_obj) do
        { type: :fax, params: { tone: 'CED' } }
      end

      it "handles parameters" do
        subject.detect(type: :fax, tone: 'CED', timeout: timeout)
      end
    end

    context "with machine" do
      let(:detect_obj) do
        { type: :machine, params: { initial_timeout: 10 } }
      end

      it "handles parameters" do
        subject.detect(type: :machine, initial_timeout: 10, timeout: timeout)
      end

      describe "#detect_answering_machine" do
        it "handles parameters" do
          subject.detect_answering_machine(initial_timeout: 10, timeout: timeout)
        end
      end
    end
  end

  describe "#record" do
    let(:record_double) { double('Record', wait_for: nil) }

    let(:type) { 'audio' }
    let(:beep) { true }
    let(:audio_format) { 'mp3' }
    let(:stereo) { true }
    let(:direction) { 'both' }
    let(:initial_timeout) { 5 }
    let(:end_silence_timeout) { 10 }
    let(:terminators) { '12' }

    let(:record_hash) do
      {
        "#{type}": 
        { 
          beep: beep,
          format: audio_format,
          stereo: stereo,
          direction: direction,
          initial_timeout: initial_timeout,
          end_silence_timeout: end_silence_timeout,
          terminators: terminators
        } 
      }
    end

    before do
      expect(Signalwire::Relay::Calling::Record).to receive(:new).with(call: subject, record: record_hash).and_return(record_double)
    end
    
    it "instantiates the component from an hash" do
      subject.record(**record_hash)
    end

    it "instantiates the component from keyword parameters" do
      subject.record(type: 'audio', beep: beep, format: audio_format, stereo: stereo, direction: direction, initial_timeout: initial_timeout, end_silence_timeout: end_silence_timeout, terminators: terminators)
    end      
  end

  describe "#tap_media" do
    let(:tap_obj) { { type: 'audio', params: { direction: 'listen'} } }
    let(:device_obj) { {type: 'rtp', params: { addr: '127.0.0.1', port: '8081'} } }

    before do
      expect(Signalwire::Relay::Calling::Tap).to receive(:new).with(call: subject, tap: tap_obj, device: device_obj).and_return(double('Tap', wait_for: nil, execute: nil))
    end

    it "accepts hash parameters" do
      subject.tap_media(tap: tap_obj, device: device_obj)
    end

    it "accepts keyword parameters" do
      subject.tap_media(audio_direction: 'listen', target_addr: '127.0.0.1', target_port: '8081')
    end

    context "async version" do
      it "accepts keyword parameters" do
        subject.tap_media!(audio_direction: 'listen', target_addr: '127.0.0.1', target_port: '8081')
      end
    end
  end
end
