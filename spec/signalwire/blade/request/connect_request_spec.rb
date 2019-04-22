# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::ConnectRequest do
  let(:session_id) { nil }
  let(:subject) { Signalwire::Blade::ConnectRequest.new session_id }

  context 'certified' do
    before :each do
      stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_PROJECT', '')
      stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_TOKEN', '')
    end

    context 'without a sessionid' do
      it 'serializes to a Blade command' do
        expect(subject.to_json).to eq "{\"jsonrpc\":\"2.0\",\"id\":\"#{subject.id}\",\"method\":\"blade.connect\",\"params\":{\"version\":{\"major\":2,\"minor\":1,\"revision\":0}}}"
      end
    end

    context 'with a sessionid' do
      let(:session_id) { SecureRandom.uuid }
      it 'serializes to a Blade command' do
        expect(subject.to_json).to eq "{\"jsonrpc\":\"2.0\",\"id\":\"#{subject.id}\",\"method\":\"blade.connect\",\"params\":{\"version\":{\"major\":2,\"minor\":1,\"revision\":0},\"sessionid\":\"#{session_id}\"}}"
      end
    end
  end

  describe 'uncertified' do
    before :each do
      stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_PROJECT', 'project')
      stub_const('Signalwire::Blade::EnvVars::SIGNALWIRE_API_TOKEN', 'token')
    end

    context 'without a sessionid' do
      it 'serializes to a Blade command' do
        expect(subject.to_json).to eq "{\"jsonrpc\":\"2.0\",\"id\":\"#{subject.id}\",\"method\":\"blade.connect\",\"params\":{\"version\":{\"major\":2,\"minor\":1,\"revision\":0},\"authentication\":{\"project\":\"project\",\"token\":\"token\"}}}"
      end
    end

    context 'with a sessionid' do
      let(:session_id) { SecureRandom.uuid }
      it 'serializes to a Blade command' do
        expect(subject.to_json).to eq "{\"jsonrpc\":\"2.0\",\"id\":\"#{subject.id}\",\"method\":\"blade.connect\",\"params\":{\"version\":{\"major\":2,\"minor\":1,\"revision\":0},\"sessionid\":\"#{session_id}\",\"authentication\":{\"project\":\"project\",\"token\":\"token\"}}}"
      end
    end
  end

end
