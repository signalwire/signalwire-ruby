require 'spec_helper'

describe Signalwire::Relay::Call do
  include_context :mock_connection

  let(:call_hash) { mock_call_hash }

  let(:client) { Signalwire::Relay::Client.new(
    project: 'myproject', 
    token: 'mytoken', 
    signalwire_space_url: 'myspace.signalwire.com')
  }

  subject { described_class.new(client, call_hash[:params][:params]) }

  describe ".from_event" do  

    let(:incoming_event) { Signalwire::Relay::Event.new(
      id: SecureRandom.uuid, 
      event_type: 'calling.call.receive', 
      params: call_hash)
    }

    it "populates the call properly" do
      call = described_class.from_event(client, incoming_event)
      expect(call.id).to eq call_hash[:params][:params][:call_id]
      expect(call.state).to eq 'created'
      expect(call.from).to eq call_hash[:params][:params][:device][:params][:from]
    end
  end

  describe '#play' do
    let(:media) { [{ "type": "tts", 
      "params": { 
        "text": "the quick brown fox jumps over the lazy dog", 
        "language": "en-US", "gender": "male" 
        } 
      }] 
    }

    it 'executes a command and returns the Play object' do
      expect(subject).to receive(:execute_call_command).and_return(true)
      play_obj = subject.play(media)
      expect(play_obj).to be_a Signalwire::Relay::Calling::PlayMediaAction
    end
  end

  describe 'connect_state_change' do
    let(:connect_params) do
      {
        params: {
          connect_state: 'connected',
          call_id: subject.id,
          node_id: "some-node-id" 
        }
      }
    end

    let(:connect_event) { Signalwire::Relay::Event.new(id: SecureRandom.uuid, event_type: 'calling.call.connect', params: connect_params) }

    it 'sets the connect state and fires the event' do
      subject.on :connect_state_change do |event|
        expect(event).to eq({ previous_state: nil, state: "connected" })
      end

      subject.trigger_handler :event, connect_event
    end
  end
end