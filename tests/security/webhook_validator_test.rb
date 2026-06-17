# frozen_string_literal: true

# Cross-language SDK contract: every port must implement Scheme A (hex
# HMAC-SHA1 over url+rawBody for JSON/RELAY) and Scheme B (base64 HMAC-SHA1
# over url+sortedFormParams for cXML/Compat) per
# ``porting-sdk/webhooks.md``. This file is the Ruby translation of the
# Python reference test suite.

require 'minitest/autorun'
require 'base64'
require 'cgi'
require 'openssl'

require_relative '../../lib/signalwire/security/webhook_validator'

module SecurityTests
  WV = SignalWire::Security::WebhookValidator

  # ---------------------------------------------------------------------
  # Canonical test vectors from porting-sdk/webhooks.md
  # ---------------------------------------------------------------------

  VECTOR_A = {
    signing_key: 'PSKtest1234567890abcdef',
    url: 'https://example.ngrok.io/webhook',
    raw_body: '{"event":"call.state","params":{"call_id":"abc-123","state":"answered"}}',
    expected: 'c3c08c1fefaf9ee198a100d5906765a6f394bf0f'
  }.freeze

  VECTOR_B_PARAMS = {
    'CallSid' => 'CA1234567890ABCDE',
    'Caller' => '+14158675309',
    'Digits' => '1234',
    'From' => '+14158675309',
    'To' => '+18005551212'
  }.freeze

  VECTOR_B = {
    signing_key: '12345',
    url: 'https://mycompany.com/myapp.php?foo=1&bar=2',
    params: VECTOR_B_PARAMS,
    expected: 'RSOYDt4T1cUTdK1PDd93/VVr8B8='
  }.freeze

  VECTOR_C = {
    signing_key: 'PSKtest1234567890abcdef',
    raw_body: '{"event":"call.state"}',
    url: 'https://example.ngrok.io/webhook?bodySHA256=' \
         '69f3cbfc18e386ef8236cb7008cd5a54b7fed637a8cb3373b5a1591d7f0fd5f4',
    expected: 'dfO9ek8mxyFtn2nMz24plPmPfIY='
  }.freeze

  module_function

  # Build an x-www-form-urlencoded body that round-trips through the
  # validator's parse_form_body back to the same key/value pairs.
  def form_encoded(params)
    params.map { |k, v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}" }.join('&')
  end

  def b64_sig(key, url, params = {})
    concat = url
    params.keys.sort.each { |k| concat += "#{k}#{params[k]}" }
    Base64.strict_encode64(OpenSSL::HMAC.digest('SHA1', key, concat))
  end
end

# =====================================================================
# Scheme A — RELAY/JSON (hex)
# =====================================================================

class WebhookValidatorSchemeATest < Minitest::Test
  WV = SecurityTests::WV
  VECTOR_A = SecurityTests::VECTOR_A

  def test_positive_canonical_vector
    # Vector A: known JSON body + URL + key produces the known hex digest.
    assert_equal true,
                 WV.validate_webhook_signature(
                   VECTOR_A[:signing_key],
                   VECTOR_A[:expected],
                   VECTOR_A[:url],
                   VECTOR_A[:raw_body]
                 )
  end

  def test_negative_tampered_body
    # Vector A: same key/url, body changed → returns false.
    tampered = VECTOR_A[:raw_body].sub('answered', 'ringing')

    assert_equal false,
                 WV.validate_webhook_signature(
                   VECTOR_A[:signing_key],
                   VECTOR_A[:expected],
                   VECTOR_A[:url],
                   tampered
                 )
  end

  def test_negative_wrong_key
    # Different signing key against the same vector → false.
    assert_equal false,
                 WV.validate_webhook_signature(
                   'wrong-key',
                   VECTOR_A[:expected],
                   VECTOR_A[:url],
                   VECTOR_A[:raw_body]
                 )
  end

  def test_negative_wrong_url
    # Same body/key, different URL path → false (URL is part of the digest).
    assert_equal false,
                 WV.validate_webhook_signature(
                   VECTOR_A[:signing_key],
                   VECTOR_A[:expected],
                   'https://example.ngrok.io/different',
                   VECTOR_A[:raw_body]
                 )
  end
end

# =====================================================================
# Scheme B — Compat/cXML (base64 form)
# =====================================================================

class WebhookValidatorSchemeBTest < Minitest::Test
  WV = SecurityTests::WV
  VECTOR_B = SecurityTests::VECTOR_B
  VECTOR_C = SecurityTests::VECTOR_C

  def test_positive_canonical_form_vector
    # Vector B: form params via raw body → matches the canonical Twilio digest.
    body = SecurityTests.form_encoded(VECTOR_B[:params])

    assert_equal true,
                 WV.validate_webhook_signature(
                   VECTOR_B[:signing_key],
                   VECTOR_B[:expected],
                   VECTOR_B[:url],
                   body
                 )
  end

  def test_positive_via_validate_request_dict
    # validate_request(..., Hash) goes straight to Scheme B with parsed params.
    assert_equal true,
                 WV.validate_request(
                   VECTOR_B[:signing_key],
                   VECTOR_B[:expected],
                   VECTOR_B[:url],
                   VECTOR_B[:params]
                 )
  end

  def test_positive_via_validate_request_array_of_pairs
    # validate_request also accepts pre-parsed [key, value] pairs.
    pairs = VECTOR_B[:params].to_a

    assert_equal true,
                 WV.validate_request(
                   VECTOR_B[:signing_key],
                   VECTOR_B[:expected],
                   VECTOR_B[:url],
                   pairs
                 )
  end

  def test_body_sha256_canonical_vector
    # Vector C: JSON body on compat surface, signature over URL with bodySHA256.
    assert_equal true,
                 WV.validate_webhook_signature(
                   VECTOR_C[:signing_key],
                   VECTOR_C[:expected],
                   VECTOR_C[:url],
                   VECTOR_C[:raw_body]
                 )
  end

  def test_body_sha256_mismatch_rejected
    # If URL's bodySHA256 doesn't match sha256(raw_body), reject — even
    # though the HMAC-over-URL+empty would otherwise match.
    wrong_body = '{"event":"DIFFERENT"}'

    assert_equal false,
                 WV.validate_webhook_signature(
                   VECTOR_C[:signing_key],
                   VECTOR_C[:expected],
                   VECTOR_C[:url],
                   wrong_body
                 )
  end
end

# =====================================================================
# URL port normalization
# =====================================================================

class WebhookValidatorPortNormalizationTest < Minitest::Test
  WV = SecurityTests::WV

  def test_signature_with_port_accepted_when_request_has_no_port
    # Backend signed with :443 — request URL has no port → accept.
    key = 'test-key'
    url_with_port    = 'https://example.com:443/webhook'
    url_without_port = 'https://example.com/webhook'
    sig = SecurityTests.b64_sig(key, url_with_port)
    # raw_body is a non-form body; Scheme B falls back to empty params.
    assert_equal true,
                 WV.validate_webhook_signature(key, sig, url_without_port, '{}')
  end

  def test_signature_without_port_accepted_when_request_has_standard_port
    # Backend signed without port — request URL has :443 → accept.
    key = 'test-key'
    url_with_port    = 'https://example.com:443/webhook'
    url_without_port = 'https://example.com/webhook'
    sig = SecurityTests.b64_sig(key, url_without_port)

    assert_equal true,
                 WV.validate_webhook_signature(key, sig, url_with_port, '{}')
  end

  def test_http_port_80_normalization
    # http + :80 mirrors https + :443.
    key = 'test-key'
    url_with_port    = 'http://example.com:80/path'
    url_without_port = 'http://example.com/path'
    sig = SecurityTests.b64_sig(key, url_with_port)

    assert_equal true,
                 WV.validate_webhook_signature(key, sig, url_without_port, '')
  end

  def test_non_standard_port_only_tries_as_is
    # A non-standard port must NOT be silently stripped during validation;
    # signing string is taken verbatim so a mismatch must still fail.
    key = 'test-key'
    url_8080 = 'https://example.com:8080/webhook'
    sig = SecurityTests.b64_sig(key, 'https://example.com/webhook') # signed without port

    assert_equal false,
                 WV.validate_webhook_signature(key, sig, url_8080, '{}')
  end
end

# =====================================================================
# Repeated form keys
# =====================================================================

class WebhookValidatorRepeatedKeysTest < Minitest::Test
  WV = SecurityTests::WV

  def test_repeated_keys_concat_in_submission_order
    # ``To=a&To=b`` → signing string ``URL + ToaTob``, deterministic.
    key = 'test-key'
    url = 'https://example.com/hook'
    body = 'To=a&To=b'
    expected_data = url + 'ToaTob'
    sig = Base64.strict_encode64(OpenSSL::HMAC.digest('SHA1', key, expected_data))

    assert_equal true, WV.validate_webhook_signature(key, sig, url, body)
  end

  def test_repeated_keys_swapped_order_is_a_different_signature
    # ``To=b&To=a`` is a different submission and yields a different digest.
    key = 'test-key'
    url = 'https://example.com/hook'
    body_ab = 'To=a&To=b'
    body_ba = 'To=b&To=a'
    data_ab = url + 'ToaTob'
    sig_for_ab = Base64.strict_encode64(OpenSSL::HMAC.digest('SHA1', key, data_ab))

    assert_equal true,  WV.validate_webhook_signature(key, sig_for_ab, url, body_ab)
    assert_equal false, WV.validate_webhook_signature(key, sig_for_ab, url, body_ba)
  end
end

# =====================================================================
# Error modes
# =====================================================================

class WebhookValidatorErrorModesTest < Minitest::Test
  WV = SecurityTests::WV
  VECTOR_A = SecurityTests::VECTOR_A

  def test_missing_signature_returns_false
    # Empty / nil signature header → false, no exception.
    assert_equal false,
                 WV.validate_webhook_signature(
                   VECTOR_A[:signing_key],
                   '',
                   VECTOR_A[:url],
                   VECTOR_A[:raw_body]
                 )
    assert_equal false,
                 WV.validate_webhook_signature(
                   VECTOR_A[:signing_key],
                   nil,
                   VECTOR_A[:url],
                   VECTOR_A[:raw_body]
                 )
  end

  def test_missing_signing_key_raises_argument_error
    # Empty / nil signing key → ArgumentError (programming error).
    assert_raises(ArgumentError) do
      WV.validate_webhook_signature('', 'sig', VECTOR_A[:url], VECTOR_A[:raw_body])
    end
    assert_raises(ArgumentError) do
      WV.validate_webhook_signature(nil, 'sig', VECTOR_A[:url], VECTOR_A[:raw_body])
    end
  end

  def test_non_string_raw_body_raises_type_error
    # A parsed Hash mistakenly passed as raw_body → TypeError.
    assert_raises(TypeError) do
      WV.validate_webhook_signature(
        VECTOR_A[:signing_key],
        'sig',
        VECTOR_A[:url],
        { event: 'call.state' }
      )
    end
  end

  def test_malformed_signature_returns_false_without_throwing
    # Garbage signature string → false, no exception. (Explicit array, not %w[],
    # because the deliberately-malformed "%%notbase64%%" reads as a nested
    # percent literal inside %w[].)
    ['xyz', '!!!!', 'aaaaaaaaaaaaaaaaaaaaa', '%%notbase64%%'].each do |garbage|
      assert_equal false,
                   WV.validate_webhook_signature(
                     VECTOR_A[:signing_key],
                     garbage,
                     VECTOR_A[:url],
                     VECTOR_A[:raw_body]
                   )
    end
  end
end

# =====================================================================
# validate_request legacy alias dispatch
# =====================================================================

class WebhookValidateRequestDispatchTest < Minitest::Test
  WV = SecurityTests::WV
  VECTOR_A = SecurityTests::VECTOR_A
  VECTOR_B = SecurityTests::VECTOR_B

  def test_string_arg_delegates_to_combined_validator
    # A String 4th arg behaves identically to validate_webhook_signature.
    assert_equal true,
                 WV.validate_request(
                   VECTOR_A[:signing_key],
                   VECTOR_A[:expected],
                   VECTOR_A[:url],
                   VECTOR_A[:raw_body]
                 )
  end

  def test_hash_arg_runs_scheme_b_directly
    # A Hash 4th arg goes straight to Scheme B with parsed params.
    assert_equal true,
                 WV.validate_request(
                   VECTOR_B[:signing_key],
                   VECTOR_B[:expected],
                   VECTOR_B[:url],
                   VECTOR_B[:params]
                 )
  end

  def test_invalid_arg_type_raises_type_error
    # Anything other than String / Hash / Array raises TypeError.
    assert_raises(TypeError) do
      WV.validate_request(
        VECTOR_A[:signing_key],
        'sig',
        VECTOR_A[:url],
        42
      )
    end
  end
end

# =====================================================================
# Constant-time compare — read the source, not just the result
# =====================================================================

class WebhookValidatorConstantTimeCompareTest < Minitest::Test
  def test_validator_source_uses_secure_compare
    # The implementation must call Rack::Utils.secure_compare for all sig
    # comparisons. We read the source rather than time-measuring because
    # timing tests are flaky in CI and the porting-sdk spec explicitly
    # names the function to use. Other ports do the equivalent
    # (hmac.compare_digest in Python, crypto.timingSafeEqual in Node, etc.).
    src = File.read(
      File.expand_path('../../lib/signalwire/security/webhook_validator.rb', __dir__)
    )

    assert_includes src, 'Rack::Utils.secure_compare',
                    'webhook_validator must use Rack::Utils.secure_compare for signature compare'
    # And it must NOT use plain == on the expected/actual digest.
    refute_includes src, 'expected_a == signature'
    refute_includes src, 'expected_b == signature'
  end
end
