# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::NodeStore do
  describe 'populate_from_connect' do
    subject { Signalwire::Blade::NodeStore.new(double('Session')) }

    let(:this_nodeid) { SecureRandom.uuid }
    let(:peer_nodeid) { SecureRandom.uuid }
    let(:first_nodeid) { peer_nodeid }
    let(:protocol_name) { 'a_protocol_name' }
    let(:channel_name) { 'a_channel_name' }

    let(:a_protocol) do
      {
        "name": protocol_name,
        "default_rpc_execute_access": 1,
        "default_channel_broadcast_access": 1,
        "default_channel_subscribe_access": 1,
        "providers": [{
          "nodeid": this_nodeid,
          "identities": []
        }],
        "channels": [{
          "name": channel_name,
          "broadcast_access": 1,
          "subscribe_access": 1
        }]
      }
    end

    let(:connect_result) do
      {
        "routes": [
          { "nodeid": '00000000-0000-0000-0000-000000000000' },
          { "nodeid": this_nodeid },
          { "nodeid": first_nodeid }
        ],
        "protocols": [a_protocol],
        "subscriptions": [{
          "protocol": protocol_name,
          "channel": channel_name,
          "subscribers": [this_nodeid]
        }],
        "authorities":  []
      }
    end

    let(:connect_event) { Signalwire::Blade::Result.new(id: SecureRandom.uuid, result: connect_result) }

    it 'sets up the various stores' do
      subject.populate_from_connect(connect_result)
      # expect(subject.lookup_protocol(protocol_name)).to eq a_protocol
    end
  end
end
