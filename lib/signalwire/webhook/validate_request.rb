# frozen_string_literal: true

require 'openssl'

module Signalwire::Webhook
  class ValidateRequest
    attr_reader :private_key

    def initialize(private_key)
      @private_key = private_key
      raise ArgumentError, 'Private key is required' if @private_key.nil?
    end

    def validate(url, raw_body, header)
      return false if header.nil? || url.nil?

      if raw_body.is_a?(Hash) || raw_body.respond_to?(:to_unsafe_h)
        return validate_for_compatibility_api(url, raw_body, header)
      end

      payload = url + raw_body
      expected_signature = compute_signature(payload)
      valid = secure_compare(expected_signature, header)

      return true if valid

      validate_for_compatibility_api(url, raw_body, header)
    end

    private

    def validate_for_compatibility_api(url, params, signature)
      validator = Twilio::Security::RequestValidator.new(private_key)
      validator.validate(url, params, signature)
    end

    def compute_signature(payload)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), private_key, payload)
    end

    # Constant time string comparison, from ActiveSupport
    def secure_compare(a, b)
      return false if a.nil? || b.nil?
      return false unless a.bytesize == b.bytesize

      l = a.unpack "C#{a.bytesize}"

      res = 0
      b.each_byte { |byte| res |= byte ^ l.shift }
      res == 0
    end
  end
end
