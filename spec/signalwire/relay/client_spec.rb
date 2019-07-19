# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Relay::Client do
  subject { Signalwire::Relay::Client.new(project: 'myproject', token: 'mytoken') }

  describe '#clean_up_space_url' do
    it 'should add a protocol and suffix if not present' do
      expect(subject.clean_up_space_url('my.signalwire.com')).to eq 'wss://my.signalwire.com'
    end

    it 'leaves a specified URL alone' do
      expect(subject.clean_up_space_url('wss://my.someurl.com:8888/path')).to eq 'wss://my.someurl.com:8888/path'
    end
  end

  describe 'setup_events' do
    let(:blade_event) do
      {
        method: 'blade.broadcast',
        params: {
          channel: 'notifications',
          event: 'relay',
          myval: '456'
        }
      }
    end

    it 'triggers Relay events' do
      subject.once :event do |evt|
        expect(evt.dig(:params, :myval)).to eq '456'
      end

      mock_message subject.session, blade_event
    end
  end

  describe '#relay_execute' do
    let(:receive_message) { {
      "protocol": 'myprotocol',
      "method": 'call.receive',
      "params": {
        context: 'context'
      }
    } }

    it "calls the block with success on 200" do
      receive_command = nil
      allow(subject.session).to receive(:transmit) { |arg| receive_command = JSON.parse(arg) }
      async = Thread.new do
        is_success = false
        subject.calling.relay_execute receive_message, 1 do |evt, successful|
          is_success = successful
        end
        is_success
      end
      sleep 0.2
      mock_message subject.session, relay_response(receive_command['id'])
      expect(async.value).to eq :success
    end

    it "calls the block with failure on 400" do
      receive_command = nil
      allow(subject.session).to receive(:transmit) { |arg| receive_command = JSON.parse(arg) }
      async = Thread.new do
        is_success = false
        subject.calling.relay_execute receive_message, 1 do |evt, successful|
          is_success = successful
        end
        is_success
      end
      sleep 0.2
      mock_message subject.session, relay_response(receive_command['id'], '400')
      expect(async.value).to eq :failure
    end
  end

  describe "tasks" do
    it "broadcasts a task" do
      tasked = false
      subject.on :task do |task|
        tasked = true
      end

      mock_message subject.session, mock_relay_task({ here: 'there' })
      expect(tasked).to eq true
    end
  end
end
