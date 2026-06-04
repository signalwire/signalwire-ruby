# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'openssl'
require 'securerandom'
require 'base64'
require 'time'

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
      # When set true, {#debug_token} decodes token internals instead of
      # returning +{ "error" => "debug mode not enabled" }+. Mirrors the
      # Python reference's +_debug_mode+ attribute (off by default). Exposed
      # as a writer only — there is no corresponding reader on the Python
      # surface, so none is projected here.
      attr_writer :debug_mode

      # @param token_expiry_secs [Integer] seconds until tokens expire (minimum 1)
      # @param secret_key [String, nil] hex-encoded secret; generated if omitted
      def initialize(token_expiry_secs: 3600, secret_key: nil)
        @token_expiry_secs = [token_expiry_secs, 1].max
        @secret_key = secret_key || SecureRandom.hex(32)
        @debug_mode = false
        # Per-session metadata store: { call_id => { key => value } }.
        @session_metadata = {}
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

      # Return the given +call_id+, or generate a new URL-safe session
      # identifier when none is supplied.
      #
      # Matches the Python reference's stateless +create_session+: the SDK
      # does not persist sessions, it just mints an identifier callers can
      # thread through subsequent token operations.
      #
      # @param call_id [String, nil] existing call ID to reuse
      # @return [String] the resolved call ID
      def create_session(call_id = nil)
        return call_id unless call_id.nil? || call_id.empty?

        # token_urlsafe(16) in Python yields ~22 url-safe chars from 16 bytes.
        Base64.urlsafe_encode64(SecureRandom.bytes(16), padding: false)
      end

      # Legacy lifecycle hook retained for API compatibility with the Python
      # reference. The session manager is stateless with respect to
      # activation, so this accepts the call ID and reports success.
      #
      # @param _call_id [String]
      # @return [Boolean] always +true+
      def activate_session(_call_id)
        true
      end

      # Legacy lifecycle hook retained for API compatibility with the Python
      # reference. Clears any metadata accumulated for the session and
      # reports success.
      #
      # @param call_id [String]
      # @return [Boolean] always +true+
      def end_session(call_id)
        @session_metadata.delete(call_id)
        true
      end

      # Fetch the metadata hash stored for +call_id+.
      #
      # The Python reference is stateless and always returns +{}+; this port
      # keeps a real per-session store (matching the TypeScript port) so the
      # getter/setter pair round-trips, but still returns an empty hash for
      # unknown sessions — callers never get +nil+.
      #
      # @param call_id [String]
      # @return [Hash] the session's metadata, or +{}+ if none is stored
      def get_session_metadata(call_id)
        # Return a copy so callers can't mutate the internal store directly.
        (@session_metadata[call_id] || {}).dup
      end

      # Store a single +key+/+value+ pair in +call_id+'s metadata, merging
      # with anything already recorded for that session.
      #
      # Signature mirrors the Python reference's
      # +set_session_metadata(call_id, key, value)+.
      #
      # @param call_id [String]
      # @param key [String]
      # @param value [Object]
      # @return [Boolean] always +true+
      def set_session_metadata(call_id, key, value)
        bucket = (@session_metadata[call_id] ||= {})
        bucket[key] = value
        true
      end

      # Decode a token's components for inspection WITHOUT validating it.
      #
      # Requires {#debug_mode=} to have been set +true+; otherwise returns
      # +{ "error" => "debug mode not enabled" }+, matching the Python
      # reference. The returned structure mirrors Python's nested
      # +components+/+status+ shape (call_id and signature truncated to
      # 8 chars + "..." when longer).
      #
      # @param token [String]
      # @return [Hash] decoded components/status, or an error/malformed hash
      def debug_token(token)
        return { "error" => "debug mode not enabled" } unless @debug_mode

        decoded = Base64.urlsafe_decode64(token)
        parts   = decoded.split(".")
        unless parts.length == 5
          return {
            "valid_format" => false,
            "parts_count"  => parts.length,
            "token_length" => token ? token.length : 0,
          }
        end

        token_call_id, token_function, token_expiry, token_nonce, token_signature = parts

        current_time = Time.now.to_i
        begin
          expiry      = Integer(token_expiry)
          is_expired  = expiry < current_time
          expires_in  = is_expired ? 0 : expiry - current_time
          expiry_date = Time.at(expiry).iso8601
        rescue ArgumentError, TypeError
          expiry      = nil
          is_expired  = nil
          expires_in  = nil
          expiry_date = nil
        end

        {
          "valid_format" => true,
          "components" => {
            "call_id"     => truncate(token_call_id),
            "function"    => token_function,
            "expiry"      => token_expiry,
            "expiry_date" => expiry_date,
            "nonce"       => token_nonce,
            "signature"   => truncate(token_signature),
          },
          "status" => {
            "current_time"       => current_time,
            "is_expired"         => is_expired,
            "expires_in_seconds" => expires_in,
          },
        }
      rescue ArgumentError, TypeError => e
        {
          "valid_format" => false,
          "error"        => e.message,
          "token_length" => token ? token.length : 0,
        }
      end

      private

      # Truncate +str+ to "first8..." when longer than 8 chars, mirroring the
      # Python reference's debug-output redaction for call_id and signature.
      def truncate(str)
        str.length > 8 ? "#{str[0, 8]}..." : str
      end

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
