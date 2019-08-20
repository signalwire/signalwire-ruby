# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::Message do
  let(:hash) { { hello: 'world' } }
  subject { described_class.new(hash) }

  describe '#build_request' do
    it 'adds the JSONRPC and id to the message' do
      subject.payload[:foo] = 'bar'
      expect(subject.build_request).to eq(foo: 'bar', hello: 'world', id: subject.id, jsonrpc: '2.0')
    end
  end

  describe '.from_json' do
    let(:payload) do
      { 'id': 'some-id', 'someval': 'foo', 'inner': { 'innerval': 'baz' } }.to_json
    end

    let(:msg) { described_class.from_json(payload) }

    it 'sets the ID if overridden' do
      expect(msg.id).to eq 'some-id'
    end

    it 'digs' do
      expect(msg.dig(:inner, :innerval)).to eq 'baz'
    end

    it 'delegates' do
      expect(msg[:someval]).to eq 'foo'
    end
  end

  describe 'error?' do
    let(:error_hash) do
      { error: { code: '-9999', message: 'Something went horribly wrong' } }
    end

    it "returns true if error" do
      obj = described_class.new(error_hash)
      expect(obj.error?).to eq true
      expect(obj.error_code).to eq error_hash[:error][:code]
      expect(obj.error_message).to eq error_hash[:error][:message]
    end

    it "returns false if not an error" do
      expect(subject.error?).to eq false
    end
  end
end
