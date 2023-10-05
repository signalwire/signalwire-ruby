# frozen_string_literal: true

require 'openssl'

module Signalwire::Webhook
  class ValidateRequest
    attr_reader :signing_key

    def initialize(signing_key:)
      @signing_key = signing_key
    end

    def validate(signature:, url:, raw_body:)
      payload = url + raw_body
      expected_signature = compute_signature(payload)
      secure_compare(expected_signature, signature)
    end

    private

    def compute_signature(payload)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), signing_key, payload)
    end

    # Constant time string comparison, from ActiveSupport
    def secure_compare(a, b)
      return false unless a.bytesize == b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end
  end
end
