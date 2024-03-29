# frozen_string_literal: true

require 'spec_helper'

module Signalwire
  RSpec.describe Webhook::ValidateRequest do
    subject { described_class.new(private_key) }
    let(:url) { 'https://81f2-2-45-18-191.ngrok-free.app/' }
    let(:private_key) { 'PSK_7TruNcSNTxp4zNrykMj4EPzF' }
    let(:header) { 'b18500437ebb010220ddd770cbe6fd531ea0ba0d' }
    let(:body) {
      '{"call":{"call_id":"b5d63b2e-f75b-4dc8-b6d4-269b635f96c0","node_id":"fa3570ae-f8bd-42c2-83f4-9950d906c91b@us-west","segment_id":"b5d63b2e-f75b-4dc8-b6d4-269b635f96c0","call_state":"created","direction":"inbound","type":"phone","from":"+12135877632","to":"+12089806814","from_number":"+12135877632","to_number":"+12089806814","project_id":"4b7ae78a-d02e-4889-a63b-08b156d5916e","space_id":"62615f44-2a34-4235-b38b-76b5a1de6ef8"},"vars":{}}'
    }

    describe '#validate' do
      context 'when key is valid' do
        it 'validates' do
          valid = subject.validate(url, body, header)
          expect(valid).to eq(true)
        end
      end

      context 'when key is invalid' do
        let(:private_key) { 'PSK_foo' }

        it 'validates signatures do not match' do
          valid = subject.validate(url, body, header)
          expect(valid).to eq(false)
        end
      end

      context 'when url is not correct' do
        let(:url) { 'https://81f2-2-45-18-191.ngrok-free.app/bar?q=hello' }

        it 'validates signatures do not match' do
          valid = subject.validate(url, body, header)
          expect(valid).to eq(false)
        end
      end

      context 'when body is not correct' do
        let(:body) {
          '{"foo":"bar"}'
        }

        it 'validates signatures do not match' do
          valid = subject.validate(url, body, header)
          expect(valid).to eq(false)
        end
      end

      context 'when inital validation fails' do
        subject { described_class.new('12345') }

        let(:default_params) {
          {
            CallSid: 'CA1234567890ABCDE',
            Caller: '+14158675309',
            Digits: '1234',
            From: '+14158675309',
            To: '+18005551212',
          }
        }
        let(:default_signature) { 'RSOYDt4T1cUTdK1PDd93/VVr8B8=' }
        let(:request_url) { 'https://mycompany.com/myapp.php?foo=1&bar=2' }

        it 'fallback and validates the request' do
          valid = subject.validate(
            request_url,
            default_params,
            default_signature
          )
          expect(valid).to eq(true)
        end

        it 'fallback and should not validate the request' do
          valid = subject.validate(
            request_url,
            default_params,
            'wrong_one!'
          )
          expect(valid).to eq(false)
        end
      end
    end
  end
end
