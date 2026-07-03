# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Shared setup/teardown snapshotting the SWML_* env so tests are isolated.
module SecurityConfigEnvIsolation
  SSL_KEYS = %w[SWML_SSL_ENABLED SWML_SSL_CERT_PATH SWML_SSL_KEY_PATH SWML_DOMAIN
                SWML_ALLOWED_HOSTS SWML_CORS_ORIGINS SWML_USE_HSTS SWML_HSTS_MAX_AGE
                SWML_BASIC_AUTH_USER SWML_BASIC_AUTH_PASSWORD SWML_MAX_REQUEST_SIZE
                SWML_RATE_LIMIT SWML_REQUEST_TIMEOUT].freeze

  def setup
    @saved = SSL_KEYS.to_h { |k| [k, ENV.fetch(k, nil)] }
    SSL_KEYS.each { |k| ENV.delete(k) }
  end

  def teardown
    @saved.each { |k, v| v.nil? ? ENV.delete(k) : (ENV[k] = v) }
  end
end

# Real-behavior tests for defaults / hosts / CORS / headers.
class CoreSecurityConfigTest < Minitest::Test
  include SecurityConfigEnvIsolation

  def test_secure_defaults
    cfg = SignalWire::Core::SecurityConfig.new

    assert_equal false, cfg.ssl_enabled
    assert_equal ['*'], cfg.allowed_hosts
    assert_equal ['*'], cfg.cors_origins
    assert_equal 60, cfg.rate_limit
    assert_equal true, cfg.use_hsts
    assert_equal 'http', cfg.get_url_scheme
  end

  def test_ssl_enabled_from_env
    ENV['SWML_SSL_ENABLED'] = 'true'
    cfg = SignalWire::Core::SecurityConfig.new

    assert_equal true, cfg.ssl_enabled
    assert_equal 'https', cfg.get_url_scheme
  end

  def test_allowed_hosts_parsed_as_list
    ENV['SWML_ALLOWED_HOSTS'] = 'a.com, b.com ,c.com'
    cfg = SignalWire::Core::SecurityConfig.new

    assert_equal %w[a.com b.com c.com], cfg.allowed_hosts
    assert cfg.should_allow_host('b.com')
    refute cfg.should_allow_host('evil.com')
  end

  def test_wildcard_host_allows_all
    cfg = SignalWire::Core::SecurityConfig.new

    assert cfg.should_allow_host('anything.example')
  end

  def test_security_headers
    cfg = SignalWire::Core::SecurityConfig.new
    headers = cfg.get_security_headers

    assert_equal 'nosniff', headers['X-Content-Type-Options']
    assert_equal 'DENY', headers['X-Frame-Options']
    refute headers.key?('Strict-Transport-Security')
  end

  def test_hsts_header_when_https
    cfg = SignalWire::Core::SecurityConfig.new
    headers = cfg.get_security_headers(is_https: true)

    assert_equal 'max-age=31536000; includeSubDomains', headers['Strict-Transport-Security']
  end

  def test_cors_config
    ENV['SWML_CORS_ORIGINS'] = 'https://app.example'
    cfg = SignalWire::Core::SecurityConfig.new
    cors = cfg.get_cors_config

    assert_equal ['https://app.example'], cors['allow_origins']
    assert_equal true, cors['allow_credentials']
    assert_equal ['*'], cors['allow_methods']
  end
end

# Real-behavior tests for basic auth + SSL validation / context kwargs.
class CoreSecurityConfigSslTest < Minitest::Test
  include SecurityConfigEnvIsolation

  def test_basic_auth_from_env
    ENV['SWML_BASIC_AUTH_USER'] = 'alice'
    ENV['SWML_BASIC_AUTH_PASSWORD'] = 'wonderland'
    cfg = SignalWire::Core::SecurityConfig.new

    assert_equal %w[alice wonderland], cfg.get_basic_auth
  end

  def test_basic_auth_autogenerates_password
    cfg = SignalWire::Core::SecurityConfig.new
    user, pass = cfg.get_basic_auth

    assert_equal 'signalwire', user
    refute_nil pass
    refute_empty pass
    assert_equal [user, pass], cfg.get_basic_auth # stable across calls
  end

  def test_validate_ssl_config_missing_cert
    ENV['SWML_SSL_ENABLED'] = 'true'
    cfg = SignalWire::Core::SecurityConfig.new
    valid, error = cfg.validate_ssl_config

    refute valid
    assert_includes error, 'SWML_SSL_CERT_PATH'
  end

  def test_validate_ssl_config_valid_when_disabled
    cfg = SignalWire::Core::SecurityConfig.new
    valid, error = cfg.validate_ssl_config

    assert valid
    assert_nil error
  end

  def test_ssl_context_kwargs_empty_when_disabled
    cfg = SignalWire::Core::SecurityConfig.new

    assert_empty cfg.get_ssl_context_kwargs
  end

  def test_ssl_context_kwargs_with_real_cert
    Dir.mktmpdir do |dir|
      cert_path, key_path = write_self_signed(dir)
      ENV['SWML_SSL_ENABLED'] = 'true'
      ENV['SWML_SSL_CERT_PATH'] = cert_path
      ENV['SWML_SSL_KEY_PATH'] = key_path
      kwargs = SignalWire::Core::SecurityConfig.new.get_ssl_context_kwargs

      assert_equal true, kwargs[:SSLEnable]
      assert_instance_of OpenSSL::X509::Certificate, kwargs[:SSLCertificate]
    end
  end

  private

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def write_self_signed(dir)
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse('/CN=test')
    cert.public_key = key.public_key
    cert.not_before = Time.now
    cert.not_after = Time.now + 3600
    cert.sign(key, OpenSSL::Digest.new('SHA256'))
    cert_path = File.join(dir, 'cert.pem')
    key_path = File.join(dir, 'key.pem')
    File.write(cert_path, cert.to_pem)
    File.write(key_path, key.to_pem)
    [cert_path, key_path]
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
end
