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

  # ------------------------------------------------------------------
  # create_session — mints / reuses a call_id (Python parity)
  # ------------------------------------------------------------------

  def test_create_session_returns_provided_call_id
    assert_equal "my-call-id", @mgr.create_session("my-call-id"),
                 "create_session must return the call_id it was given verbatim"
  end

  def test_create_session_generates_when_absent
    id = @mgr.create_session
    assert_kind_of String, id
    refute_empty id
    # token_urlsafe(16) shape: URL-safe Base64, no + / or padding =.
    refute_match(/[+\/=]/, id, "generated session id must be URL-safe with no padding")
  end

  def test_create_session_generates_when_empty_string
    id = @mgr.create_session("")
    refute_empty id, "empty call_id should be treated as absent and regenerated"
  end

  def test_create_session_generates_unique_ids
    a = @mgr.create_session
    b = @mgr.create_session
    refute_equal a, b, "two generated session ids must differ"
  end

  # ------------------------------------------------------------------
  # activate_session / end_session — lifecycle hooks
  # ------------------------------------------------------------------

  def test_activate_session_returns_true
    assert_equal true, @mgr.activate_session("call-1")
    assert_equal true, @mgr.activate_session("any-other-id")
  end

  def test_end_session_returns_true
    assert_equal true, @mgr.end_session("call-1")
  end

  # ------------------------------------------------------------------
  # Session metadata — real store, content-shaped round-trip
  # ------------------------------------------------------------------

  def test_get_session_metadata_empty_for_unknown_session
    assert_equal({}, @mgr.get_session_metadata("never-seen"),
                 "unknown session must yield an empty hash, never nil")
    refute_nil @mgr.get_session_metadata("never-seen")
  end

  def test_set_and_get_session_metadata_roundtrip
    assert_equal true, @mgr.set_session_metadata("call-1", "caller", "Jane Doe")
    assert_equal({ "caller" => "Jane Doe" }, @mgr.get_session_metadata("call-1"),
                 "stored metadata must be readable back with the exact value")
  end

  def test_set_session_metadata_merges_multiple_keys
    @mgr.set_session_metadata("call-1", "caller", "Jane")
    @mgr.set_session_metadata("call-1", "topic", "billing")
    @mgr.set_session_metadata("call-1", "priority", 3)
    assert_equal(
      { "caller" => "Jane", "topic" => "billing", "priority" => 3 },
      @mgr.get_session_metadata("call-1"),
      "successive sets on the same session must accumulate, not replace"
    )
  end

  def test_set_session_metadata_overwrites_same_key
    @mgr.set_session_metadata("call-1", "stage", "greeting")
    @mgr.set_session_metadata("call-1", "stage", "checkout")
    assert_equal({ "stage" => "checkout" }, @mgr.get_session_metadata("call-1"),
                 "re-setting a key must overwrite the prior value")
  end

  def test_metadata_is_isolated_per_session
    @mgr.set_session_metadata("call-A", "owner", "alice")
    @mgr.set_session_metadata("call-B", "owner", "bob")
    assert_equal({ "owner" => "alice" }, @mgr.get_session_metadata("call-A")
    )
    assert_equal({ "owner" => "bob" }, @mgr.get_session_metadata("call-B")
    )
  end

  def test_get_session_metadata_returns_a_copy
    @mgr.set_session_metadata("call-1", "k", "v")
    snapshot = @mgr.get_session_metadata("call-1")
    snapshot["k"] = "mutated"
    snapshot["injected"] = "x"
    assert_equal({ "k" => "v" }, @mgr.get_session_metadata("call-1"),
                 "mutating the returned hash must not corrupt the internal store")
  end

  # ------------------------------------------------------------------
  # Full lifecycle: create -> activate -> set/get -> end -> cleared
  # ------------------------------------------------------------------

  def test_full_session_lifecycle
    call_id = @mgr.create_session
    refute_empty call_id

    assert_equal true, @mgr.activate_session(call_id)

    @mgr.set_session_metadata(call_id, "caller_name", "Pat")
    @mgr.set_session_metadata(call_id, "intent", "refund")
    assert_equal(
      { "caller_name" => "Pat", "intent" => "refund" },
      @mgr.get_session_metadata(call_id),
      "metadata accumulated during the session must be retrievable"
    )

    assert_equal true, @mgr.end_session(call_id)
    assert_equal({}, @mgr.get_session_metadata(call_id),
                 "ending a session must clear its metadata")
  end

  # ------------------------------------------------------------------
  # debug_token — gated decode without validation
  # ------------------------------------------------------------------

  def test_debug_token_disabled_by_default
    token = @mgr.create_token("get_time", "call-42")
    info = @mgr.debug_token(token)
    assert_equal({ "error" => "debug mode not enabled" }, info,
                 "debug_token must refuse to decode unless debug mode is enabled")
  end

  def test_debug_token_decodes_components_when_enabled
    @mgr.debug_mode = true
    token = @mgr.create_token("get_time", "call-99")
    info = @mgr.debug_token(token)

    assert_equal true, info["valid_format"]
    assert_equal "get_time", info["components"]["function"]
    # "call-99" is 7 chars, so it is NOT truncated.
    assert_equal "call-99", info["components"]["call_id"]
    # signature is 64 hex chars -> truncated to 8 + "..."
    assert_match(/\A[0-9a-f]{8}\.\.\.\z/, info["components"]["signature"])
    refute_empty info["components"]["nonce"]
    assert_equal false, info["status"]["is_expired"]
    assert_kind_of Integer, info["status"]["current_time"]
    assert info["status"]["expires_in_seconds"] > 0,
           "a freshly minted token should report positive seconds remaining"
  end

  def test_debug_token_truncates_long_call_id_and_signature
    @mgr.debug_mode = true
    token = @mgr.create_token("fn", "a-very-long-call-id-string")
    info = @mgr.debug_token(token)
    assert_equal "a-very-l...", info["components"]["call_id"],
                 "call_id longer than 8 chars must be truncated to first 8 + '...'"
    assert_match(/\.\.\.\z/, info["components"]["signature"])
  end

  def test_debug_token_reports_expired_token
    short = SM.new(token_expiry_secs: 1)
    short.debug_mode = true
    token = short.create_token("fn", "call-1")
    sleep 2
    info = short.debug_token(token)
    assert_equal true, info["valid_format"]
    assert_equal true, info["status"]["is_expired"]
    assert_equal 0, info["status"]["expires_in_seconds"]
  end

  def test_debug_token_malformed_when_enabled
    @mgr.debug_mode = true
    info = @mgr.debug_token("not-valid-base64!!!")
    assert_equal false, info["valid_format"]
  end

  def test_debug_token_wrong_part_count_when_enabled
    @mgr.debug_mode = true
    bad = Base64.urlsafe_encode64("a.b.c", padding: false)
    info = @mgr.debug_token(bad)
    assert_equal false, info["valid_format"]
    assert_equal 3, info["parts_count"]
  end
end
