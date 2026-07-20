# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'base64'
require 'rack'

require_relative '../logging'
require_relative '../error'

module SignalWire
  module Core
    # Unified authentication handler supporting multiple auth methods.
    #
    # Mirrors Python's ``signalwire.core.auth_handler.AuthHandler``. Provides a
    # clean pattern for handling Basic Auth, Bearer tokens, and API keys across
    # all SignalWire services. All credential comparisons are timing-safe
    # (``Rack::Utils.secure_compare``).
    #
    # Two Rack-native entry points are provided: (a) +rack_middleware+ -- a
    # Rack middleware wrapping an app so unauthenticated requests get a 401,
    # also available under the alias +flask_decorator+, and (b)
    # +rack_dependency+ -- a callable taking a Rack +env+ and returning an
    # auth-result Hash, also available under the alias +get_fastapi_dependency+.
    class AuthHandler
      # Lightweight credential carriers for HTTP Basic and Bearer
      # authorization.
      BasicCredentials = Struct.new(:username, :password)
      BearerCredentials = Struct.new(:credentials)

      attr_reader :security_config, :auth_methods

      # Initialize the auth handler with a {SecurityConfig} instance (or any
      # object exposing +get_basic_auth+ and optional +bearer_token+/+api_key+
      # readers).
      def initialize(security_config)
        @security_config = security_config
        setup_auth_methods
      end

      # Verify basic auth credentials (a {BasicCredentials} or any object
      # responding to +username+/+password+). Timing-safe.
      def verify_basic_auth(credentials)
        return false unless @auth_methods.dig('basic', 'enabled')

        basic = @auth_methods['basic']
        secure_compare(credentials.username, basic['username']) &&
          secure_compare(credentials.password, basic['password'])
      end

      # Verify a bearer token (a {BearerCredentials} or any object responding to
      # +credentials+). Timing-safe.
      def verify_bearer_token(credentials)
        return false unless @auth_methods.dig('bearer', 'enabled')

        secure_compare(credentials.credentials, @auth_methods['bearer']['token'])
      end

      # Verify an API key String. Timing-safe.
      def verify_api_key(api_key)
        return false unless @auth_methods.dig('api_key', 'enabled')

        secure_compare(api_key, @auth_methods['api_key']['key'])
      end

      # Native Rack equivalent of Python's FastAPI dependency. Returns a
      # callable (lambda) that takes a Rack +env+ and returns an auth-result
      # Hash ``{ 'authenticated' => Boolean, 'method' => String|nil }``. When
      # +optional+ is false and authentication fails, the callable raises
      # {AuthError} (carrying a 401 response). When +optional+ is true it
      # returns the result without raising.
      def rack_dependency(optional: false)
        lambda do |env|
          method = authenticate_env(env)
          authenticated = !method.nil?
          raise AuthError, unauthorized_response if !authenticated && !optional

          { 'authenticated' => authenticated, 'method' => method }
        end
      end
      alias get_fastapi_dependency rack_dependency

      # Native Rack equivalent of Python's Flask decorator. Given a Rack app
      # (any object responding to +call(env)+), returns a wrapping app that
      # enforces authentication: authenticated requests pass through, others
      # get an HTTP 401 with a WWW-Authenticate challenge.
      def rack_middleware(app)
        handler = self
        lambda do |env|
          if handler.send(:authenticate_env, env)
            app.call(env)
          else
            handler.send(:log_auth_failure, env)
            handler.send(:unauthorized_response)
          end
        end
      end
      alias flask_decorator rack_middleware

      # Get information about configured auth methods (never includes secrets).
      def get_auth_info
        info = {}
        info['basic'] = basic_auth_info if @auth_methods.dig('basic', 'enabled')
        info['bearer'] = bearer_auth_info if @auth_methods.dig('bearer', 'enabled')
        info['api_key'] = api_key_info if @auth_methods.dig('api_key', 'enabled')
        info
      end

      private

      def setup_auth_methods
        @auth_methods = {}
        username, password = @security_config.get_basic_auth
        @auth_methods['basic'] = { 'enabled' => true, 'username' => username, 'password' => password }

        bearer_token = config_attr(:bearer_token)
        @auth_methods['bearer'] = { 'enabled' => true, 'token' => bearer_token } if bearer_token

        api_key = config_attr(:api_key)
        return unless api_key

        header = config_attr(:api_key_header) || 'X-API-Key'
        @auth_methods['api_key'] = { 'enabled' => true, 'key' => api_key, 'header' => header }
      end

      def config_attr(name)
        @security_config.respond_to?(name) ? @security_config.public_send(name) : nil
      end

      # Try each configured auth method against a Rack env. Returns the name of
      # the method that authenticated ('bearer'/'api_key'/'basic'), or nil.
      def authenticate_env(env)
        return 'bearer' if bearer_env_ok?(env)
        return 'api_key' if api_key_env_ok?(env)
        return 'basic' if basic_env_ok?(env)

        nil
      end

      def bearer_env_ok?(env)
        return false unless @auth_methods.dig('bearer', 'enabled')

        header = env['HTTP_AUTHORIZATION'].to_s
        return false unless header.start_with?('Bearer ')

        verify_bearer_token(BearerCredentials.new(header[7..]))
      end

      def api_key_env_ok?(env)
        return false unless @auth_methods.dig('api_key', 'enabled')

        rack_header = "HTTP_#{@auth_methods['api_key']['header'].upcase.tr('-', '_')}"
        key = env[rack_header]
        !key.nil? && verify_api_key(key)
      end

      def basic_env_ok?(env)
        return false unless @auth_methods.dig('basic', 'enabled')

        creds = parse_basic_auth(env['HTTP_AUTHORIZATION'].to_s)
        return false if creds.nil?

        verify_basic_auth(creds)
      end

      def parse_basic_auth(header)
        return nil unless header.start_with?('Basic ')

        decoded = Base64.decode64(header[6..])
        user, _sep, pass = decoded.partition(':')
        BasicCredentials.new(user, pass)
      rescue ArgumentError
        nil
      end

      def secure_compare(lhs, rhs)
        Rack::Utils.secure_compare(lhs.to_s, rhs.to_s)
      end

      def unauthorized_response
        [401,
         { 'content-type' => 'text/plain', 'www-authenticate' => 'Basic realm="SignalWire Service"' },
         ['Authentication required']]
      end

      def log_auth_failure(env)
        logger.warn("auth_failed ip=#{env['REMOTE_ADDR']} method=#{env['REQUEST_METHOD']} " \
                    "path=#{env['PATH_INFO']}")
      end

      def logger
        return @logger if defined?(@logger)

        @logger = SignalWire::Logging.logger('auth_handler')
      end

      def basic_auth_info
        { 'enabled' => true, 'username' => @auth_methods['basic']['username'] }
      end

      def bearer_auth_info
        { 'enabled' => true, 'hint' => 'Use Authorization: Bearer <token>' }
      end

      def api_key_info
        header = @auth_methods['api_key']['header']
        { 'enabled' => true, 'header' => header, 'hint' => "Use #{header}: <key>" }
      end
    end

    # Raised by the {AuthHandler#rack_dependency} callable when required
    # authentication fails. Carries the Rack 401 response tuple.
    class AuthError < SignalWire::Error
      attr_reader :response

      def initialize(response)
        @response = response
        super('Invalid authentication credentials')
      end
    end
  end
end
