# frozen_string_literal: true

require 'openssl'

module Signalwire::Webhook
  class ValidateRequest
    attr_reader :private_key

    def initialize(private_key:)
      @private_key = private_key
    end

    def validate(header:, url:, raw_body:)
      payload = url + raw_body
      expected_signature = compute_signature(payload)
      secure_compare(expected_signature, header)
    end

    private

    def compute_signature(payload)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), private_key, payload)
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
