# frozen_string_literal: true

require 'minitest/autorun'
require 'openssl'

require_relative '../../lib/signalwire/security/webhook_validator'

# hex(HMAC-SHA256(key, url + raw_body)) — the X-SignalWire-Sha256-Signature
# header. Same message construction as Scheme A, stronger hash.
# Parity: signalwire-python tests/unit/security/test_webhook_validator.py
# TestSchemeASha256 (core/security/webhook_validator.py:282).
class WebhookValidatorSha256Test < Minitest::Test
  WV = SignalWire::Security::WebhookValidator
  KEY = 'PSKtest1234567890abcdef'
  URL = 'https://example.ngrok.io/webhook'
  BODY = '{"event":"call.state","params":{"call_id":"abc-123","state":"answered"}}'
  SHA1_VECTOR = 'c3c08c1fefaf9ee198a100d5906765a6f394bf0f'

  def sign(key, url, body)
    OpenSSL::HMAC.hexdigest('SHA256', key, url + body)
  end

  def test_positive_vector
    sig = sign(KEY, URL, BODY)

    assert_equal 64, sig.length
    assert WV.validate_webhook_signature_sha256(KEY, sig, URL, BODY)
  end

  def test_sha1_signature_not_accepted_as_sha256
    refute WV.validate_webhook_signature_sha256(KEY, SHA1_VECTOR, URL, BODY)
  end

  def test_negative_tampered_body
    refute WV.validate_webhook_signature_sha256(KEY, sign(KEY, URL, BODY), URL, BODY.sub('answered', 'ringing'))
  end

  def test_negative_wrong_key
    refute WV.validate_webhook_signature_sha256('wrong-key', sign(KEY, URL, BODY), URL, BODY)
  end

  def test_missing_signature_returns_false
    refute WV.validate_webhook_signature_sha256(KEY, '', URL, BODY)
    refute WV.validate_webhook_signature_sha256(KEY, nil, URL, BODY)
  end

  def test_missing_signing_key_raises
    assert_raises(ArgumentError) { WV.validate_webhook_signature_sha256('', 'deadbeef', URL, BODY) }
  end

  def test_parsed_body_raises
    assert_raises(TypeError) { WV.validate_webhook_signature_sha256(KEY, 'deadbeef', URL, { 'a' => 1 }) }
  end
end
