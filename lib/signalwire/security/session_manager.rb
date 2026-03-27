# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'openssl'
require 'securerandom'
require 'base64'

module SignalWire
  module Security
    # Stateless HMAC-SHA256 session manager for secure SWAIG tool tokens.
    #
    # Tokens are self-contained: all information needed for validation is
    # encoded inside the token itself. No server-side session state is stored.
    #
    #   mgr = SessionManager.new(token_expiry_secs: 900)
    #   token = mgr.create_token("lookup_order", "call-abc-123")
    #   mgr.validate_token("lookup_order", token, "call-abc-123") # => true
    #
    class SessionManager
      # @param token_expiry_secs [Integer] seconds until tokens expire (minimum 1)
      # @param secret_key [String, nil] hex-encoded secret; generated if omitted
      def initialize(token_expiry_secs: 3600, secret_key: nil)
        @token_expiry_secs = [token_expiry_secs, 1].max
        @secret_key = secret_key || SecureRandom.hex(32)
      end

      # Create a secure, self-contained token for a function call.
      #
      # Token format (before Base64):
      #   call_id.function_name.expiry_timestamp.nonce.hmac_hex
      #
      # @param function_name [String]
      # @param call_id [String]
      # @return [String] URL-safe Base64-encoded token
      def create_token(function_name, call_id)
        expiry = (Time.now.to_i + @token_expiry_secs).to_s
        nonce  = SecureRandom.hex(8)

        message   = "#{call_id}:#{function_name}:#{expiry}:#{nonce}"
        signature = compute_hmac(message)

        token_raw = "#{call_id}.#{function_name}.#{expiry}.#{nonce}.#{signature}"
        Base64.urlsafe_encode64(token_raw, padding: false)
      end

      # Validate a function-call token.
      #
      # Checks:
      # 1. Correct Base64 / structure (5 dot-separated parts)
      # 2. HMAC signature (timing-safe comparison)
      # 3. Function name matches
      # 4. Call ID matches
      # 5. Token not expired
      #
      # @param function_name [String]
      # @param token [String] the token to validate
      # @param call_id [String]
      # @return [Boolean]
      def validate_token(function_name, token, call_id)
        return false if token.nil? || token.empty?
        return false if call_id.nil? || call_id.empty?

        decoded = Base64.urlsafe_decode64(token)
        parts   = decoded.split(".")
        return false unless parts.length == 5

        token_call_id, token_function, token_expiry, token_nonce, token_signature = parts

        # Verify function name
        return false unless token_function == function_name

        # Verify call ID
        return false unless token_call_id == call_id

        # Check expiry
        expiry = Integer(token_expiry)
        return false if expiry < Time.now.to_i

        # Recompute HMAC and compare with timing-safe comparison
        message           = "#{token_call_id}:#{token_function}:#{token_expiry}:#{token_nonce}"
        expected_signature = compute_hmac(message)

        secure_compare(token_signature, expected_signature)
      rescue ArgumentError, TypeError
        # Bad Base64, bad integer, etc.
        false
      end

      private

      # Compute HMAC-SHA256 of +message+ using the instance secret key.
      # @return [String] hex digest
      def compute_hmac(message)
        OpenSSL::HMAC.hexdigest("SHA256", @secret_key, message)
      end

      # Timing-safe string comparison.
      #
      # Uses OpenSSL.fixed_length_secure_compare when the strings are the same
      # length (which they should be for hex HMAC digests). Falls back to a
      # double-HMAC comparison for differing lengths.
      def secure_compare(a, b)
        return false if a.nil? || b.nil?

        if a.bytesize == b.bytesize
          OpenSSL.fixed_length_secure_compare(a, b)
        else
          # Different length => definitely not equal, but still constant-time
          false
        end
      rescue NoMethodError
        # Fallback for older Ruby without fixed_length_secure_compare:
        # compare HMAC of both values so timing doesn't leak content.
        ha = OpenSSL::HMAC.digest("SHA256", @secret_key, a.to_s)
        hb = OpenSSL::HMAC.digest("SHA256", @secret_key, b.to_s)
        ha == hb
      end
    end
  end
end
