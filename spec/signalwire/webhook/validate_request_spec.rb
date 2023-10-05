# frozen_string_literal: true

require 'spec_helper'

module Signalwire
  RSpec.describe Webhook::ValidateRequest do
    subject { described_class.new(signing_key: signing_key) }
    let(:url) { 'https://81f2-2-45-18-191.ngrok-free.app/' }
    let(:signing_key) { 'PSK_7TruNcSNTxp4zNrykMj4EPzF' }
    let(:signature) { 'b18500437ebb010220ddd770cbe6fd531ea0ba0d' }
    let(:body) {
      '{"call":{"call_id":"b5d63b2e-f75b-4dc8-b6d4-269b635f96c0","node_id":"fa3570ae-f8bd-42c2-83f4-9950d906c91b@us-west","segment_id":"b5d63b2e-f75b-4dc8-b6d4-269b635f96c0","call_state":"created","direction":"inbound","type":"phone","from":"+12135877632","to":"+12089806814","from_number":"+12135877632","to_number":"+12089806814","project_id":"4b7ae78a-d02e-4889-a63b-08b156d5916e","space_id":"62615f44-2a34-4235-b38b-76b5a1de6ef8"},"vars":{}}'
    }

    describe '#validate' do
      context 'when signing key is valid' do
        it 'validates' do
          valid = subject.validate(signature: signature, url: url, raw_body: body)
          expect(valid).to eq(true)
        end
      end

      context 'when signing key is invalid' do
        let(:signing_key) { 'PSK_foo' }

        it 'validates signatures do not match' do
          valid = subject.validate(signature: signature, url: url, raw_body: body)
          expect(valid).to eq(false)
        end
      end

      context 'when url is not correct' do
        let(:url) { 'https://81f2-2-45-18-191.ngrok-free.app/bar?q=hello' }

        it 'validates signatures do not match' do
          valid = subject.validate(signature: signature, url: url, raw_body: body)
          expect(valid).to eq(false)
        end
      end

      context 'when body is not correct' do
        let(:body) {
          '{"foo":"bar"}'
        }

        it 'validates signatures do not match' do
          valid = subject.validate(signature: signature, url: url, raw_body: '{"foo":"bar"}')
          expect(valid).to eq(false)
        end
      end
    end
  end
end
