# frozen_string_literal: true

require 'minitest/autorun'
require 'base64'
require_relative '../lib/signalwire/security/session_manager'

class SessionManagerTest < Minitest::Test
  SM = SignalWire::Security::SessionManager

  def setup
    @mgr = SM.new(token_expiry_secs: 3600)
  end

  # ------------------------------------------------------------------
  # Happy path
  # ------------------------------------------------------------------

  def test_create_and_validate_token
    token = @mgr.create_token("lookup_order", "call-abc-123")
    assert_kind_of String, token
    refute_empty token

    assert @mgr.validate_token("lookup_order", token, "call-abc-123"),
           "Token should validate with correct function_name and call_id"
  end

  def test_token_is_url_safe_base64
    token = @mgr.create_token("fn", "call-1")
    # URL-safe Base64 uses - and _ instead of + and /
    refute_match(/[+\/]/, token, "Token should be URL-safe Base64")
  end

  def test_decoded_token_has_five_parts
    token = @mgr.create_token("fn", "call-1")
    decoded = Base64.urlsafe_decode64(token)
    parts = decoded.split(".")
    assert_equal 5, parts.length, "Decoded token must have 5 dot-separated parts"
  end

  # ------------------------------------------------------------------
  # Wrong function name
  # ------------------------------------------------------------------

  def test_wrong_function_name_fails
    token = @mgr.create_token("lookup_order", "call-abc-123")
    refute @mgr.validate_token("wrong_function", token, "call-abc-123"),
           "Token must not validate with wrong function name"
  end

  # ------------------------------------------------------------------
  # Wrong call ID
  # ------------------------------------------------------------------

  def test_wrong_call_id_fails
    token = @mgr.create_token("lookup_order", "call-abc-123")
    refute @mgr.validate_token("lookup_order", token, "call-wrong-id"),
           "Token must not validate with wrong call_id"
  end

  # ------------------------------------------------------------------
  # Expired token
  # ------------------------------------------------------------------

  def test_expired_token_fails
    short_mgr = SM.new(token_expiry_secs: 1)
    token = short_mgr.create_token("fn", "call-1")
    sleep 2
    refute short_mgr.validate_token("fn", token, "call-1"),
           "Expired token must not validate"
  end

  # ------------------------------------------------------------------
  # Tampered token
  # ------------------------------------------------------------------

  def test_tampered_signature_fails
    token = @mgr.create_token("fn", "call-1")
    decoded = Base64.urlsafe_decode64(token)
    parts = decoded.split(".")

    # Flip a character in the signature
    sig = parts[4]
    tampered_sig = sig[0] == 'a' ? 'b' + sig[1..] : 'a' + sig[1..]
    parts[4] = tampered_sig

    tampered_token = Base64.urlsafe_encode64(parts.join("."), padding: false)
    refute @mgr.validate_token("fn", tampered_token, "call-1"),
           "Tampered token must not validate"
  end

  def test_tampered_expiry_fails
    token = @mgr.create_token("fn", "call-1")
    decoded = Base64.urlsafe_decode64(token)
    parts = decoded.split(".")

    # Change expiry to far future
    parts[2] = (Time.now.to_i + 999999).to_s
    tampered_token = Base64.urlsafe_encode64(parts.join("."), padding: false)
    refute @mgr.validate_token("fn", tampered_token, "call-1"),
           "Token with tampered expiry must not validate (HMAC mismatch)"
  end

  def test_tampered_call_id_in_token_fails
    token = @mgr.create_token("fn", "call-1")
    decoded = Base64.urlsafe_decode64(token)
    parts = decoded.split(".")

    # Change call_id inside the token
    parts[0] = "call-hacked"
    tampered_token = Base64.urlsafe_encode64(parts.join("."), padding: false)
    refute @mgr.validate_token("fn", tampered_token, "call-1"),
           "Token with tampered call_id must not validate"
  end

  # ------------------------------------------------------------------
  # Empty / nil inputs
  # ------------------------------------------------------------------

  def test_nil_token_fails
    refute @mgr.validate_token("fn", nil, "call-1")
  end

  def test_empty_token_fails
    refute @mgr.validate_token("fn", "", "call-1")
  end

  def test_nil_call_id_fails
    token = @mgr.create_token("fn", "call-1")
    refute @mgr.validate_token("fn", token, nil)
  end

  def test_empty_call_id_fails
    token = @mgr.create_token("fn", "call-1")
    refute @mgr.validate_token("fn", token, "")
  end

  def test_garbage_token_fails
    refute @mgr.validate_token("fn", "not-valid-base64!!!", "call-1")
  end

  def test_wrong_part_count_fails
    bad_token = Base64.urlsafe_encode64("a.b.c", padding: false)
    refute @mgr.validate_token("fn", bad_token, "call-1")
  end

  # ------------------------------------------------------------------
  # Different secret keys
  # ------------------------------------------------------------------

  def test_different_secret_key_fails
    mgr_a = SM.new(secret_key: "aaaaaaaabbbbbbbbccccccccdddddddd" * 2)
    mgr_b = SM.new(secret_key: "1111111122222222333333334444444" * 2 + "55")

    token = mgr_a.create_token("fn", "call-1")
    refute mgr_b.validate_token("fn", token, "call-1"),
           "Token from a different secret must not validate"
  end

  # ------------------------------------------------------------------
  # Custom secret key
  # ------------------------------------------------------------------

  def test_custom_secret_key_roundtrip
    mgr = SM.new(token_expiry_secs: 60, secret_key: "my-test-secret-key-for-testing")
    token = mgr.create_token("my_tool", "call-99")
    assert mgr.validate_token("my_tool", token, "call-99")
  end

  # ------------------------------------------------------------------
  # Minimum expiry
  # ------------------------------------------------------------------

  def test_minimum_expiry_is_one
    mgr = SM.new(token_expiry_secs: 0)
    # Should still be 1 second minimum, so token created now should be valid
    token = mgr.create_token("fn", "call-1")
    assert mgr.validate_token("fn", token, "call-1")
  end

  def test_negative_expiry_clamped
    mgr = SM.new(token_expiry_secs: -100)
    token = mgr.create_token("fn", "call-1")
    # With 1-second minimum, token should be valid immediately
    assert mgr.validate_token("fn", token, "call-1")
  end
end
