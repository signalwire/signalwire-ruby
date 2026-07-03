# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'openssl'
require 'securerandom'

require_relative 'config_loader'
require_relative '../logging'

module SignalWire
  module Core
    # Unified security configuration for SignalWire services.
    #
    # Mirrors Python's ``signalwire.core.security_config.SecurityConfig``.
    # Provides centralized security settings (SSL, allowed hosts, CORS,
    # security headers, basic auth) that are consumed by the web/agent
    # services, ensuring consistent behavior.
    class SecurityConfig
      # Security environment variable names.
      SSL_ENABLED = 'SWML_SSL_ENABLED'
      SSL_CERT_PATH = 'SWML_SSL_CERT_PATH'
      SSL_KEY_PATH = 'SWML_SSL_KEY_PATH'
      SSL_DOMAIN = 'SWML_DOMAIN'
      SSL_VERIFY_MODE = 'SWML_SSL_VERIFY_MODE'

      ALLOWED_HOSTS = 'SWML_ALLOWED_HOSTS'
      CORS_ORIGINS = 'SWML_CORS_ORIGINS'
      MAX_REQUEST_SIZE = 'SWML_MAX_REQUEST_SIZE'
      RATE_LIMIT = 'SWML_RATE_LIMIT'
      REQUEST_TIMEOUT = 'SWML_REQUEST_TIMEOUT'
      USE_HSTS = 'SWML_USE_HSTS'
      HSTS_MAX_AGE = 'SWML_HSTS_MAX_AGE'

      BASIC_AUTH_USER = 'SWML_BASIC_AUTH_USER'
      BASIC_AUTH_PASSWORD = 'SWML_BASIC_AUTH_PASSWORD'

      # Defaults (secure by default).
      DEFAULTS = {
        SSL_ENABLED => false,
        SSL_VERIFY_MODE => 'CERT_REQUIRED',
        ALLOWED_HOSTS => '*',
        CORS_ORIGINS => '*',
        MAX_REQUEST_SIZE => 10 * 1024 * 1024,
        RATE_LIMIT => 60,
        REQUEST_TIMEOUT => 30,
        USE_HSTS => true,
        HSTS_MAX_AGE => 31_536_000
      }.freeze

      attr_accessor :ssl_enabled, :ssl_cert_path, :ssl_key_path, :domain, :ssl_verify_mode,
                    :allowed_hosts, :cors_origins, :max_request_size, :rate_limit,
                    :request_timeout, :use_hsts, :hsts_max_age, :basic_auth_user, :basic_auth_password

      # Initialize security configuration. Defaults are applied first, then
      # environment variables (backward compatibility), then a config file if
      # available (highest priority).
      def initialize(config_file: nil, service_name: nil)
        set_defaults
        load_from_env
        load_config_file(config_file, service_name)
      end

      # Load configuration from environment variables.
      def load_from_env
        load_ssl_from_env
        load_hosts_from_env
        load_hsts_from_env
        self.basic_auth_user = ENV.fetch(BASIC_AUTH_USER, nil)
        self.basic_auth_password = ENV.fetch(BASIC_AUTH_PASSWORD, nil)
      end

      # Validate SSL configuration. Returns a two-element Array
      # ``[is_valid, error_message]`` (+error_message+ is +nil+ when valid).
      def validate_ssl_config
        return [true, nil] unless ssl_enabled
        return [false, 'SSL enabled but SWML_SSL_CERT_PATH not set'] unless ssl_cert_path
        return [false, 'SSL enabled but SWML_SSL_KEY_PATH not set'] unless ssl_key_path
        return [false, "SSL certificate file not found: #{ssl_cert_path}"] unless File.exist?(ssl_cert_path)
        return [false, "SSL key file not found: #{ssl_key_path}"] unless File.exist?(ssl_key_path)

        [true, nil]
      end

      # Get native TLS options for binding a WEBrick HTTPS server. Returns an
      # empty Hash when SSL is disabled or the configuration fails validation.
      #
      # Ruby idiom note: Python returns uvicorn ``ssl_certfile``/``ssl_keyfile``
      # kwargs; Ruby returns WEBrick/OpenSSL option keys (:SSLEnable,
      # :SSLCertificate, :SSLPrivateKey) ready to merge into a WEBrick config.
      def get_ssl_context_kwargs
        return {} unless ssl_enabled

        valid, = validate_ssl_config
        return {} unless valid

        {
          SSLEnable: true,
          SSLCertificate: OpenSSL::X509::Certificate.new(File.read(ssl_cert_path)),
          SSLPrivateKey: OpenSSL::PKey.read(File.read(ssl_key_path))
        }
      end

      # Get basic auth credentials, generating a random password if not set.
      # Returns a two-element Array ``[username, password]``.
      def get_basic_auth
        username = basic_auth_user || 'signalwire'
        if basic_auth_password.nil? || basic_auth_password.empty?
          self.basic_auth_password = SecureRandom.urlsafe_base64(32)
          warn_basic_auth_autogen(username)
        end
        [username, basic_auth_password]
      end

      # Get security headers to add to responses. When +is_https+ is true and
      # HSTS is enabled, a Strict-Transport-Security header is included.
      def get_security_headers(is_https: false)
        headers = {
          'X-Content-Type-Options' => 'nosniff',
          'X-Frame-Options' => 'DENY',
          'X-XSS-Protection' => '1; mode=block',
          'Referrer-Policy' => 'strict-origin-when-cross-origin'
        }
        headers['Strict-Transport-Security'] = "max-age=#{hsts_max_age}; includeSubDomains" if is_https && use_hsts
        headers
      end

      # Check if a host is allowed (``*`` in the allowed list allows all).
      def should_allow_host(host)
        return true if allowed_hosts.include?('*')

        allowed_hosts.include?(host)
      end

      # Get CORS configuration.
      def get_cors_config
        {
          'allow_origins' => cors_origins,
          'allow_credentials' => true,
          'allow_methods' => ['*'],
          'allow_headers' => ['*']
        }
      end

      # Get the URL scheme based on SSL configuration.
      def get_url_scheme
        ssl_enabled ? 'https' : 'http'
      end

      # Log the current security configuration.
      def log_config(service_name)
        logger.info("security_config_loaded service=#{service_name} #{config_summary}")
      end

      private

      def logger
        @logger ||= SignalWire::Logging.logger('security_config')
      end

      def config_summary
        has_basic_auth = !(basic_auth_user.nil? || basic_auth_password.nil?)
        "ssl_enabled=#{ssl_enabled} domain=#{domain.inspect} allowed_hosts=#{allowed_hosts.inspect} " \
          "cors_origins=#{cors_origins.inspect} max_request_size=#{max_request_size} " \
          "rate_limit=#{rate_limit} use_hsts=#{use_hsts} has_basic_auth=#{has_basic_auth}"
      end

      def set_defaults
        set_ssl_defaults
        set_host_defaults
        self.use_hsts = DEFAULTS[USE_HSTS]
        self.hsts_max_age = DEFAULTS[HSTS_MAX_AGE]
        self.basic_auth_user = nil
        self.basic_auth_password = nil
      end

      def set_host_defaults
        self.allowed_hosts = parse_list(DEFAULTS[ALLOWED_HOSTS])
        self.cors_origins = parse_list(DEFAULTS[CORS_ORIGINS])
        self.max_request_size = DEFAULTS[MAX_REQUEST_SIZE]
        self.rate_limit = DEFAULTS[RATE_LIMIT]
        self.request_timeout = DEFAULTS[REQUEST_TIMEOUT]
      end

      def set_ssl_defaults
        self.ssl_enabled = DEFAULTS[SSL_ENABLED]
        self.ssl_cert_path = nil
        self.ssl_key_path = nil
        self.domain = nil
        self.ssl_verify_mode = DEFAULTS[SSL_VERIFY_MODE]
      end

      def load_ssl_from_env
        self.ssl_enabled = %w[true 1 yes].include?(ENV[SSL_ENABLED].to_s.downcase)
        self.ssl_cert_path = ENV.fetch(SSL_CERT_PATH, nil)
        self.ssl_key_path = ENV.fetch(SSL_KEY_PATH, nil)
        self.domain = ENV.fetch(SSL_DOMAIN, nil)
        self.ssl_verify_mode = ENV.fetch(SSL_VERIFY_MODE, DEFAULTS[SSL_VERIFY_MODE])
      end

      def load_hosts_from_env
        self.allowed_hosts = parse_list(env_or_default(ALLOWED_HOSTS))
        self.cors_origins = parse_list(env_or_default(CORS_ORIGINS))
        self.max_request_size = env_or_default(MAX_REQUEST_SIZE).to_i
        self.rate_limit = env_or_default(RATE_LIMIT).to_i
        self.request_timeout = env_or_default(REQUEST_TIMEOUT).to_i
      end

      def env_or_default(key)
        ENV.fetch(key, DEFAULTS[key])
      end

      def load_hsts_from_env
        use_hsts_env = ENV[USE_HSTS].to_s.downcase
        self.use_hsts = use_hsts_env.empty? ? DEFAULTS[USE_HSTS] : (use_hsts_env != 'false')
        self.hsts_max_age = ENV.fetch(HSTS_MAX_AGE, DEFAULTS[HSTS_MAX_AGE]).to_i
      end

      def load_config_file(config_file, service_name)
        config_file ||= ConfigLoader.find_config_file(service_name)
        return unless config_file

        loader = ConfigLoader.new([config_file])
        return unless loader.has_config

        section = loader.get_section('security')
        return if section.nil? || section.empty?

        apply_security_section(section)
      end

      def apply_security_section(section)
        apply_ssl_section(section)
        apply_hosts_section(section)
        apply_hsts_section(section)
        apply_auth_section(section)
      end

      def apply_ssl_section(section)
        self.ssl_enabled = section['ssl_enabled'] if section.key?('ssl_enabled')
        self.ssl_cert_path = section['ssl_cert_path'] if section.key?('ssl_cert_path')
        self.ssl_key_path = section['ssl_key_path'] if section.key?('ssl_key_path')
        self.domain = section['domain'] if section.key?('domain')
        self.ssl_verify_mode = section['ssl_verify_mode'] if section.key?('ssl_verify_mode')
      end

      def apply_hosts_section(section)
        self.allowed_hosts = parse_list(section['allowed_hosts']) if section.key?('allowed_hosts')
        self.cors_origins = parse_list(section['cors_origins']) if section.key?('cors_origins')
        apply_int_section(section)
      end

      def apply_int_section(section)
        self.max_request_size = section['max_request_size'].to_i if section.key?('max_request_size')
        self.rate_limit = section['rate_limit'].to_i if section.key?('rate_limit')
        self.request_timeout = section['request_timeout'].to_i if section.key?('request_timeout')
      end

      def apply_hsts_section(section)
        self.use_hsts = section['use_hsts'] if section.key?('use_hsts')
        self.hsts_max_age = section['hsts_max_age'].to_i if section.key?('hsts_max_age')
      end

      def apply_auth_section(section)
        auth_config = section['auth']
        return unless auth_config.is_a?(Hash)

        basic = auth_config['basic']
        return unless basic.is_a?(Hash)

        self.basic_auth_user = basic['user'] if basic.key?('user')
        self.basic_auth_password = basic['password'] if basic.key?('password')
      end

      # Parse a comma-separated String (or pass an Array through) into a list.
      def parse_list(value)
        return value if value.is_a?(Array)
        return ['*'] if value == '*'

        value.split(',').map(&:strip).reject(&:empty?)
      end

      def warn_basic_auth_autogen(username)
        return if @basic_auth_autogen_warned

        logger.warn("basic_auth_password_autogenerated username=#{username}: no SWML_BASIC_AUTH_PASSWORD " \
                    'in environment and no password passed; generated a random password that exists only ' \
                    'in this process. External callers will get HTTP 401 unless they read it from this ' \
                    "process's env. Set SWML_BASIC_AUTH_USER / SWML_BASIC_AUTH_PASSWORD to suppress.")
        @basic_auth_autogen_warned = true
      end
    end
  end
end
