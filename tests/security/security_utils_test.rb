# frozen_string_literal: true

# Cross-language SDK contract: every port ships the three security hygiene
# helpers mirroring the Python reference
# ``signalwire.core.security.security_utils`` (filter_sensitive_headers,
# redact_url, is_valid_hostname) and the TypeScript ``SecurityUtils``. This
# file is the Ruby translation of the Python reference test suite.

require 'minitest/autorun'

require_relative '../../lib/signalwire/security/security_utils'

module SecurityUtilsTests
  SU = SignalWire::Security::SecurityUtils

  class FilterSensitiveHeadersTest < Minitest::Test
    SENSITIVE = {
      'Authorization' => 'Bearer secret', 'Cookie' => 'session=abc',
      'X-API-Key' => 'key123', 'Proxy-Authorization' => 'Basic creds',
      'Set-Cookie' => 'session=xyz'
    }.freeze
    NON_SENSITIVE = { 'Content-Type' => 'application/json', 'X-Request-Id' => 'req-1' }.freeze

    def test_removes_sensitive_headers_case_insensitively
      filtered = SU.filter_sensitive_headers(SENSITIVE.merge(NON_SENSITIVE))

      assert_equal(NON_SENSITIVE, filtered)
    end

    def test_matches_sensitive_keys_regardless_of_casing
      headers = { 'AUTHORIZATION' => 'a', 'cookie' => 'b', 'x-api-key' => 'c', 'Keep' => 'd' }

      filtered = SU.filter_sensitive_headers(headers)

      assert_equal({ 'Keep' => 'd' }, filtered)
    end

    def test_preserves_original_casing_of_kept_keys
      headers = { 'Content-Type' => 'text/plain', 'X-Custom-Header' => 'v' }

      filtered = SU.filter_sensitive_headers(headers)

      assert_equal(%w[Content-Type X-Custom-Header], filtered.keys)
    end

    def test_returns_a_new_hash_and_does_not_mutate_input
      headers = { 'Authorization' => 'secret', 'Accept' => 'application/json' }

      filtered = SU.filter_sensitive_headers(headers)

      refute_same(headers, filtered)
      assert_equal({ 'Authorization' => 'secret', 'Accept' => 'application/json' }, headers)
    end

    def test_empty_input_returns_empty_hash
      assert_equal({}, SU.filter_sensitive_headers({}))
    end

    def test_nil_input_returns_empty_hash
      assert_equal({}, SU.filter_sensitive_headers(nil))
    end
  end

  class RedactUrlTest < Minitest::Test
    def test_masks_password_in_userinfo
      assert_equal(
        'https://user:****@host/path',
        SU.redact_url('https://user:secret@host/path')
      )
    end

    def test_masks_password_with_other_schemes
      assert_equal('wss://admin:****@example.com', SU.redact_url('wss://admin:hunter2@example.com'))
    end

    def test_url_without_credentials_is_unchanged
      url = 'https://host/path?query=1'

      assert_equal(url, SU.redact_url(url))
    end

    def test_url_with_only_username_is_unchanged
      url = 'https://user@host/path'

      assert_equal(url, SU.redact_url(url))
    end

    def test_non_string_input_is_returned_as_is
      assert_nil(SU.redact_url(nil))
      assert_equal(42, SU.redact_url(42))
    end
  end

  class IsValidHostnameTest < Minitest::Test
    def test_accepts_plain_hostname
      assert(SU.is_valid_hostname('example.com'))
    end

    def test_accepts_hostname_with_port_digits_and_dashes
      assert(SU.is_valid_hostname('my-host.sub.example.com'))
    end

    def test_rejects_empty_string
      refute(SU.is_valid_hostname(''))
    end

    def test_rejects_nil
      refute(SU.is_valid_hostname(nil))
    end

    def test_rejects_whitespace
      refute(SU.is_valid_hostname('exam ple.com'))
      refute(SU.is_valid_hostname("host\t"))
      refute(SU.is_valid_hostname("host\n"))
    end

    def test_rejects_slashes_and_backslashes
      refute(SU.is_valid_hostname('host/path'))
      refute(SU.is_valid_hostname('host\\path'))
    end

    def test_rejects_control_characters
      refute(SU.is_valid_hostname("host\x00"))
      refute(SU.is_valid_hostname("host\x1f"))
      refute(SU.is_valid_hostname("host\x7f"))
    end
  end
end
