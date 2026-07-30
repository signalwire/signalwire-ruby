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

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Security — webhook signature validation, session tokens and request hardening.
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
      # Framework-free decomposed validation core (the SignalWire webhook
      # signing scheme's combined validator, decomposed at the HTTP
      # boundary). Given the raw HTTP request primitives — method, full public
      # URL, headers, raw body — plus the Signing Key, return ``nil`` when the
      # request is authentic (let it through) or a Rack-shaped
      # ``[status, headers, body]`` rejection triple when it must be blocked.
      #
      # This is the SAME decision the Rack ``#call`` wrapper makes; ``#call``
      # simply extracts these primitives from the Rack ``env`` and delegates
      # here. Exposing it separately lets non-Rack hosts (Sinatra route blocks,
      # AWS Lambda handlers, plain scripts) reuse the exact validation logic
      # without constructing a middleware object. A ``nil`` return is the pass
      # signal; a triple is the ready-to-serve 403.
      #
      # The ``X-SignalWire-Signature`` header is honored, with
      # ``X-Twilio-Signature`` accepted as a legacy cXML/Compatibility alias.
      # Header lookup is case-insensitive (HTTP header names are).
      #
      # @param method [String] the request HTTP method (``POST`` etc.). Accepted
      #   as part of the validation signature; validation applies
      #   to any method (the Rack wrapper does the method allowlisting).
      # @param url [String] the full public URL SignalWire POSTed to (scheme,
      #   host, optional port, path, query) — see webhooks.md URL reconstruction.
      # @param headers [Hash{String=>String}] request headers (any casing).
      # @param body [String] the raw request body bytes as a UTF-8 String,
      #   BEFORE any JSON / form parsing.
      # @param signing_key [String] the customer Signing Key (required).
      #
      # @return [Array(Integer, Hash, Array<String>), nil] ``nil`` to pass;
      #   a ``[403, headers, body]`` Rack triple to reject.
      #
      # @raise [ArgumentError] when ``signing_key`` is missing.
      #
      # The ``method`` param is part of the decomposed validator's signature
      # but is not consulted here — the Rack wrapper does method allowlisting;
      # the signature check itself is method-agnostic.
      def self.validate(method, url, headers, body, signing_key:) # rubocop:disable Lint/UnusedMethodArgument
        # Missing signing key is a programming error, not a validation failure —
        # raise (webhooks.md "Error modes"), consistent with the L1 validator.
        raise ArgumentError, 'signing_key is required' if signing_key.nil? || signing_key.to_s.empty?

        signature = WebhookValidator._signature_from_headers(headers)
        return WebhookValidator._forbidden_triple if signature.nil? || signature.empty?

        ok =
          begin
            WebhookValidator.validate_webhook_signature(signing_key, signature, url, body.to_s)
          rescue TypeError
            # A non-String body slipped through — treat as a plain rejection
            # rather than leaking the boundary error to the caller / client.
            false
          end
        ok ? nil : WebhookValidator._forbidden_triple
      end

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
        raw_body = read_raw_body(env)
        env[RAW_BODY_ENV_KEY] = raw_body

        url = reconstruct_url(env)
        # Delegate the pass/reject decision to the framework-free {validate}
        # core. It returns nil to pass, or a Rack [status, headers, body]
        # triple to reject.
        rejection = self.class.validate(
          env['REQUEST_METHOD'].to_s, url, rack_signature_headers(env), raw_body,
          signing_key: @signing_key
        )
        return rejection if rejection

        @app.call(env)
      end

      private

      # @api private — surface the signature header(s) from the Rack env as a
      # plain header Hash the decomposed #validate can read (both the canonical
      # and the legacy-compat header name, un-CGI-mangled).
      def rack_signature_headers(env)
        {
          'X-SignalWire-Signature' => env[SIGNALWIRE_SIGNATURE_HEADER],
          'X-Twilio-Signature' => env[TWILIO_COMPAT_SIGNATURE_HEADER]
        }.compact
      end

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
      def read_raw_body(env)
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
      # Reconstruct the public URL SignalWire POSTed to.
      #
      # Resolution order (highest priority first):
      # 1. ``SWML_PROXY_URL_BASE`` env var (joined with the request path + query).
      # 2. ``X-Forwarded-Proto`` / ``X-Forwarded-Host`` headers, when
      #    ``trust_proxy`` is true and X-Forwarded-Host is present.
      # 3. ``scheme://host[:port]/path?query`` derived from the rack env.
      def reconstruct_url(env)
        path = env['PATH_INFO'].to_s
        path = '/' if path.empty?
        query = env['QUERY_STRING'].to_s
        path_and_query = query.empty? ? path : "#{path}?#{query}"

        proxy_base_url(path_and_query) ||
          forwarded_url(env, path_and_query) ||
          rack_derived_url(env, path_and_query)
      end

      # @api private
      # Strategy 1: explicit SWML_PROXY_URL_BASE env var (highest priority).
      def proxy_base_url(path_and_query)
        proxy_base = ENV.fetch('SWML_PROXY_URL_BASE', nil)
        return unless proxy_base && !proxy_base.empty?

        "#{proxy_base.sub(%r{/+\z}, '')}#{path_and_query}"
      end

      # @api private
      # Strategy 2: X-Forwarded-Proto / X-Forwarded-Host (when trust_proxy).
      def forwarded_url(env, path_and_query)
        return unless @trust_proxy

        fwd_host = env['HTTP_X_FORWARDED_HOST']
        return unless fwd_host && !fwd_host.empty?

        fwd_proto = env['HTTP_X_FORWARDED_PROTO'] || 'https'
        "#{fwd_proto}://#{fwd_host}#{path_and_query}"
      end

      # @api private
      # Strategy 3: scheme://host[:port]/path?query derived from the rack env.
      def rack_derived_url(env, path_and_query)
        scheme = env['rack.url_scheme'] || 'http'
        host = env['HTTP_HOST'] || env['SERVER_NAME']
        host_with_port = host_with_port(scheme, host, env['SERVER_PORT'])
        "#{scheme}://#{host_with_port}#{path_and_query}"
      end

      # @api private
      # Only include the port if it's non-standard AND not already in HTTP_HOST.
      # The "already has a port" and "no port needed" cases both yield host but
      # are distinct conditions; keeping them separate reads clearer than merging.
      def host_with_port(scheme, host, port)
        return host if host&.include?(':')
        return "#{host}:#{port}" if port && _nonstandard_port?(scheme, port)

        host
      end

      # @api private
      def _nonstandard_port?(scheme, port)
        (scheme == 'http' && port.to_s != '80') ||
          (scheme == 'https' && port.to_s != '443')
      end
    end
  end
end
