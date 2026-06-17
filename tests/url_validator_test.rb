# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.

# Parity tests for SignalWire::Utils::UrlValidator.validate_url. Mirrors
# signalwire-python tests/unit/utils/test_url_validator.py. The DNS
# resolver is stubbed via the .resolver= setter so the suite stays
# hermetic.

require 'minitest/autorun'
require_relative '../lib/signalwire/utils/url_validator'

class UrlValidatorTest < Minitest::Test
  V = SignalWire::Utils::UrlValidator

  def setup
    @prev_resolver = V._resolver
    @prev_env = ENV.fetch('SWML_ALLOW_PRIVATE_URLS', nil)
    ENV.delete('SWML_ALLOW_PRIVATE_URLS')
    V._resolver = nil
  end

  def teardown
    V._resolver = @prev_resolver
    if @prev_env
      ENV['SWML_ALLOW_PRIVATE_URLS'] = @prev_env
    else
      ENV.delete('SWML_ALLOW_PRIVATE_URLS')
    end
  end

  def stub_resolver(ip)
    V._resolver = ->(_host) { [ip] }
  end

  def stub_failed_resolver
    V._resolver = ->(_host) {}
  end

  # --- Scheme ----------------------------------------------------------

  def test_http_scheme_allowed
    stub_resolver('1.2.3.4')

    assert V.validate_url('http://example.com')
  end

  def test_https_scheme_allowed
    stub_resolver('1.2.3.4')

    assert V.validate_url('https://example.com')
  end

  def test_ftp_scheme_rejected
    refute V.validate_url('ftp://example.com')
  end

  def test_file_scheme_rejected
    refute V.validate_url('file:///etc/passwd')
  end

  def test_javascript_scheme_rejected
    refute V.validate_url('javascript:alert(1)')
  end

  # --- Hostname --------------------------------------------------------

  def test_no_hostname_rejected
    refute V.validate_url('http://')
  end

  def test_unresolvable_hostname_rejected
    stub_failed_resolver

    refute V.validate_url('http://nonexistent.invalid')
  end

  # --- Blocked ranges --------------------------------------------------

  def test_loopback_ipv4_rejected
    stub_resolver('127.0.0.1')

    refute V.validate_url('http://localhost')
  end

  def test_rfc1918_10_rejected
    stub_resolver('10.0.0.5')

    refute V.validate_url('http://internal')
  end

  def test_rfc1918_192_rejected
    stub_resolver('192.168.1.1')

    refute V.validate_url('http://router')
  end

  def test_rfc1918_172_rejected
    stub_resolver('172.16.0.1')

    refute V.validate_url('http://corp')
  end

  def test_link_local_metadata_rejected
    stub_resolver('169.254.169.254')

    refute V.validate_url('http://metadata')
  end

  def test_zero_ip_rejected
    stub_resolver('0.0.0.0')

    refute V.validate_url('http://void')
  end

  def test_ipv6_loopback_rejected
    stub_resolver('::1')

    refute V.validate_url('http://[::1]')
  end

  def test_ipv6_link_local_rejected
    stub_resolver('fe80::1')

    refute V.validate_url('http://link-local')
  end

  def test_ipv6_private_rejected
    stub_resolver('fc00::1')

    refute V.validate_url('http://ipv6-private')
  end

  def test_public_ip_allowed
    stub_resolver('8.8.8.8')

    assert V.validate_url('http://dns.google')
  end

  # --- allow_private bypass -------------------------------------------

  def test_allow_private_param_bypasses_check
    # No resolver stub: allow_private short-circuits before DNS.
    assert V.validate_url('http://10.0.0.5', true)
  end

  def test_env_var_bypasses_check
    ENV['SWML_ALLOW_PRIVATE_URLS'] = 'true'

    assert V.validate_url('http://10.0.0.5')
  end

  def test_env_var_yes_bypasses_check
    ENV['SWML_ALLOW_PRIVATE_URLS'] = 'YES'

    assert V.validate_url('http://10.0.0.5')
  end

  def test_env_var_1_bypasses_check
    ENV['SWML_ALLOW_PRIVATE_URLS'] = '1'

    assert V.validate_url('http://10.0.0.5')
  end

  def test_env_var_false_does_not_bypass
    ENV['SWML_ALLOW_PRIVATE_URLS'] = 'false'
    stub_resolver('10.0.0.5')

    refute V.validate_url('http://internal')
  end

  def test_blocked_networks_has_all_nine
    assert_equal 9, V::BLOCKED_NETWORKS.size
  end
end
