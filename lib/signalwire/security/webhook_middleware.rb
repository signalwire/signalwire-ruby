# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Rack middleware for SignalWire webhook signature validation.
#
# This adapter wraps {SignalWire::Security::WebhookValidator} so it can be
# inserted into any Rack pipeline (Rails, Sinatra, plain Rack).
#
# Why a custom middleware rather than vanilla Rack?
#
# - We MUST capture the raw bytes BEFORE any JSON / form parser consumes
#   the stream — re-serialization changes whitespace and key order, which
#   breaks the Scheme A digest. The middleware reads ``rack.input``, then
#   rewinds the IO and stashes the bytes on
#   ``env['signalwire.raw_body']`` so downstream handlers can re-parse
#   without re-reading the stream.
# - Reverse-proxy / ngrok deployments need the URL the platform POSTed
#   to, which differs from the URL the SDK sees. The middleware honors
#   ``X-Forwarded-Proto`` / ``X-Forwarded-Host`` when ``trust_proxy``
#   is true, plus the ``SWML_PROXY_URL_BASE`` env var, with the request
#   URL as last resort.
# - The legacy cXML/Compatibility scheme used the ``X-Twilio-Signature``
#   header. We accept it as an alias of ``X-SignalWire-Signature`` so users
#   migrating from the legacy SDK can keep their callers unchanged.
#
# Usage::
#
#     use SignalWire::Security::WebhookMiddleware,
#         signing_key: ENV['SIGNALWIRE_SIGNING_KEY'],
#         trust_proxy: true,
#         paths: ['/', '/swaig', '/post_prompt']

require 'rack'
require_relative 'webhook_validator'

module SignalWire
  module Security
    # Rack middleware that rejects webhook requests with bad signatures.
    #
    # Configure with the customer's Signing Key (and optional ``trust_proxy``
    # to honor X-Forwarded headers). Mount upstream of any body-parsing
    # middleware so the raw bytes survive intact.
    class WebhookMiddleware
      SIGNALWIRE_SIGNATURE_HEADER = 'HTTP_X_SIGNALWIRE_SIGNATURE'
      TWILIO_COMPAT_SIGNATURE_HEADER = 'HTTP_X_TWILIO_SIGNATURE'

      # Key under which the captured raw body is stashed on the request env.
      RAW_BODY_ENV_KEY = 'signalwire.raw_body'

      # @param app [#call] the wrapped Rack app.
      # @param signing_key [String] customer Signing Key (required, non-empty).
      # @param trust_proxy [Boolean] honor X-Forwarded-Proto / X-Forwarded-Host
      #   when reconstructing the request URL. Default false — proxy headers
      #   are spoofable, so opt in only when you control the proxy.
      # @param paths [Array<String>, nil] when set, only apply the validation
      #   on these PATH_INFO values; everything else passes through. When nil,
      #   apply to every request.
      # @param methods [Array<String>, nil] limit to these HTTP methods. When
      #   nil, apply to every method.
      #
      # @raise [ArgumentError] when ``signing_key`` is missing.
      def initialize(app, signing_key:, trust_proxy: false, paths: nil, methods: ['POST'])
        raise ArgumentError, 'signing_key is required' if signing_key.nil? || signing_key.to_s.empty?

        @app          = app
        @signing_key  = signing_key
        @trust_proxy  = trust_proxy
        @paths        = paths.nil? ? nil : Array(paths).map(&:to_s)
        @methods      = methods.nil? ? nil : Array(methods).map { |m| m.to_s.upcase }
      end

      # @api private
      def call(env)
        return @app.call(env) unless _applies?(env)

        # Capture raw body BEFORE any other middleware reads the stream.
        raw_body = _read_raw_body(env)
        env[RAW_BODY_ENV_KEY] = raw_body

        signature = _extract_signature_header(env)
        return _forbidden if signature.nil? || signature.empty?

        url = _reconstruct_url(env)

        valid = begin
          WebhookValidator.validate_webhook_signature(@signing_key, signature, url, raw_body)
        rescue ArgumentError, TypeError
          # Programming errors at the boundary — never leak which branch
          # tripped. Reject the request without raising.
          return _forbidden
        end

        return _forbidden unless valid

        @app.call(env)
      end

      private

      # @api private
      def _applies?(env)
        if @methods
          method = env['REQUEST_METHOD'].to_s.upcase
          return false unless @methods.include?(method)
        end
        if @paths
          path = env['PATH_INFO'].to_s
          # Exact match — paths is intentionally a tight allowlist.
          return false unless @paths.include?(path)
        end
        true
      end

      # @api private
      def _read_raw_body(env)
        input = env['rack.input']
        return '' if input.nil?

        body = input.read
        # Rewind so downstream middleware / handlers can read the body too.
        # Some Rack inputs (e.g. Tempfile-backed) are seekable; StringIO is
        # always rewindable.
        input.rewind if input.respond_to?(:rewind)
        body.to_s
      rescue StandardError
        ''
      end

      # @api private
      def _extract_signature_header(env)
        sig = env[SIGNALWIRE_SIGNATURE_HEADER]
        sig = env[TWILIO_COMPAT_SIGNATURE_HEADER] if sig.nil? || sig.empty?
        sig
      end

      # @api private
      # Reconstruct the public URL SignalWire POSTed to.
      #
      # Resolution order (highest priority first):
      # 1. ``SWML_PROXY_URL_BASE`` env var (joined with the request path + query).
      # 2. ``X-Forwarded-Proto`` / ``X-Forwarded-Host`` headers, when
      #    ``trust_proxy`` is true and X-Forwarded-Host is present.
      # 3. ``scheme://host[:port]/path?query`` derived from the rack env.
      def _reconstruct_url(env)
        path = env['PATH_INFO'].to_s
        path = '/' if path.empty?
        query = env['QUERY_STRING'].to_s
        path_and_query = query.empty? ? path : "#{path}?#{query}"

        proxy_base = ENV['SWML_PROXY_URL_BASE']
        return "#{proxy_base.sub(%r{/+\z}, '')}#{path_and_query}" if proxy_base && !proxy_base.empty?

        if @trust_proxy
          fwd_host  = env['HTTP_X_FORWARDED_HOST']
          fwd_proto = env['HTTP_X_FORWARDED_PROTO'] || 'https'
          if fwd_host && !fwd_host.empty?
            return "#{fwd_proto}://#{fwd_host}#{path_and_query}"
          end
        end

        scheme = env['rack.url_scheme'] || 'http'
        host = env['HTTP_HOST'] || env['SERVER_NAME']
        port = env['SERVER_PORT']
        # Only include port if it's non-standard AND not already in HTTP_HOST.
        host_with_port =
          if host && host.include?(':')
            host
          elsif port && (
            (scheme == 'http'  && port.to_s != '80') ||
            (scheme == 'https' && port.to_s != '443')
          )
            "#{host}:#{port}"
          else
            host
          end

        "#{scheme}://#{host_with_port}#{path_and_query}"
      end

      # @api private
      def _forbidden
        # No body detail — never leak which branch tripped.
        [403, { 'content-type' => 'text/plain' }, ['']]
      end
    end
  end
end
