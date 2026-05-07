# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Webhook signature validation for SignalWire-signed HTTP requests.
#
# Implements both schemes from porting-sdk/webhooks.md:
#
# - Scheme A (RELAY/SWML/JSON): hex(HMAC-SHA1(key, url + raw_body))
# - Scheme B (Compat/cXML form): base64(HMAC-SHA1(key, url + sortedFormParams))
#   with optional bodySHA256 query-param fallback for JSON-on-compat-surface.
#
# Public API:
#     SignalWire::Security::WebhookValidator.validate_webhook_signature(
#         signing_key, signature, url, raw_body) -> Boolean
#     SignalWire::Security::WebhookValidator.validate_request(
#         signing_key, signature, url, params_or_raw_body) -> Boolean
#
# All comparisons use ``Rack::Utils.secure_compare`` (constant-time) so the
# secret is not leaked over repeated requests.

require 'base64'
require 'cgi'
require 'digest'
require 'openssl'
require 'rack/utils'
require 'uri'

module SignalWire
  module Security
    # Stateless validator for SignalWire-signed webhook requests.
    #
    # Both Scheme A (JSON, hex digest) and Scheme B (form-encoded, base64
    # digest with bodySHA256 fallback) per porting-sdk/webhooks.md are
    # tried by the combined entry point.
    #
    # The two public entry points are exposed via ``module_function`` so
    # they can be invoked as ``WebhookValidator.validate_webhook_signature(...)``.
    # All internal helpers are deliberately ``_``-prefixed and private so
    # they don't pollute the public surface (``audit_no_cheat_tests`` and
    # ``signature_dump.rb`` skip ``_``-prefixed methods).
    module WebhookValidator
      # Validate a SignalWire webhook signature against both schemes.
      #
      # @param signing_key [String] Customer's Signing Key from the Dashboard.
      #   UTF-8 string, secret. ``nil`` / empty raises ``ArgumentError`` —
      #   that's a programming error, not a validation failure.
      # @param signature [String, nil] The ``X-SignalWire-Signature`` header
      #   value (or ``X-Twilio-Signature`` for cXML compat). Missing / empty
      #   returns false without raising.
      # @param url [String] The full URL SignalWire POSTed to (scheme, host,
      #   optional port, path, query). Must match what the platform saw —
      #   see the URL reconstruction section of porting-sdk/webhooks.md.
      # @param raw_body [String] The raw request body bytes as a UTF-8 string,
      #   BEFORE any JSON / form parsing. Must be a ``String`` — passing a
      #   parsed Hash raises ``TypeError``.
      #
      # @return [Boolean] true if the signature matches either Scheme A or
      #   Scheme B (with port-normalization variants and optional bodySHA256
      #   fallback). false otherwise.
      #
      # @raise [ArgumentError] when ``signing_key`` is missing.
      # @raise [TypeError] when ``raw_body`` is not a String.
      def self.validate_webhook_signature(signing_key, signature, url, raw_body)
        raise ArgumentError, 'signing_key is required' if signing_key.nil? || signing_key.to_s.empty?
        unless raw_body.is_a?(String)
          raise TypeError,
                'raw_body must be a String — did you pass parsed JSON by mistake?'
        end
        return false if signature.nil? || signature.to_s.empty?

        # ------------------------------------------------------------------
        # Scheme A — RELAY/SWML/JSON: hex(HMAC-SHA1(key, url + raw_body))
        # ------------------------------------------------------------------
        expected_a = _hex_hmac_sha1(signing_key, url.to_s + raw_body)
        return true if _safe_eq(expected_a, signature)

        # ------------------------------------------------------------------
        # Scheme B — Compat/cXML form: base64(HMAC-SHA1(key, url + sorted_concat))
        # Try parsed form params and the empty-params fallback (for JSON on
        # the compat surface). Try with-port and without-port URL variants.
        # ------------------------------------------------------------------
        parsed_params = _parse_form_body(raw_body)
        param_shapes  = [parsed_params, []]

        _candidate_urls(url.to_s).each do |candidate_url|
          param_shapes.each do |shape|
            concat = _sorted_concat_params(shape)
            expected_b = _b64_hmac_sha1(signing_key, candidate_url + concat)
            next unless _safe_eq(expected_b, signature)

            # If the URL carries bodySHA256, the body hash must match too.
            return true if _check_body_sha256(candidate_url, raw_body)
            # bodySHA256 mismatched — keep trying other shapes/urls.
          end
        end

        false
      end

      # Legacy ``@signalwire/compatibility-api`` drop-in entry point.
      #
      # If ``params_or_raw_body`` is a ``String``, delegates to
      # {validate_webhook_signature} (Scheme A then Scheme B with parsed form).
      #
      # If it's a ``Hash`` or an array of (key, value) pairs, treats it as
      # pre-parsed form params and runs Scheme B directly (with URL port
      # normalization and optional bodySHA256 fallback).
      #
      # @param signing_key [String]
      # @param signature [String, nil]
      # @param url [String]
      # @param params_or_raw_body [String, Hash, Array, nil]
      # @return [Boolean]
      # @raise [ArgumentError] when ``signing_key`` is missing.
      # @raise [TypeError] when ``params_or_raw_body`` is neither a String,
      #   Hash, nor an array of pairs.
      def self.validate_request(signing_key, signature, url, params_or_raw_body)
        raise ArgumentError, 'signing_key is required' if signing_key.nil? || signing_key.to_s.empty?
        return false if signature.nil? || signature.to_s.empty?

        if params_or_raw_body.is_a?(String)
          return validate_webhook_signature(signing_key, signature, url, params_or_raw_body)
        end

        params_or_raw_body = [] if params_or_raw_body.nil?

        unless params_or_raw_body.is_a?(Hash) || params_or_raw_body.is_a?(Array)
          raise TypeError,
                'params_or_raw_body must be a String (raw body) or a Hash/Array of form params'
        end

        # Pre-parsed form params → Scheme B only.
        concat = _sorted_concat_params(params_or_raw_body)
        _candidate_urls(url.to_s).each do |candidate_url|
          expected_b = _b64_hmac_sha1(signing_key, candidate_url + concat)
          # bodySHA256 has no raw body to verify here — skip that check.
          return true if _safe_eq(expected_b, signature)
        end
        false
      end

      # ----------------------------------------------------------------------
      # Internal helpers (underscore-prefixed: not part of the public surface).
      # ----------------------------------------------------------------------

      # @api private
      def self._hex_hmac_sha1(key, message)
        OpenSSL::HMAC.hexdigest('SHA1', key.to_s, message.to_s)
      end

      # @api private
      def self._b64_hmac_sha1(key, message)
        Base64.strict_encode64(
          OpenSSL::HMAC.digest('SHA1', key.to_s, message.to_s)
        )
      end

      # @api private
      # Constant-time string compare. Returns false on any error so malformed
      # inputs never raise.
      def self._safe_eq(a, b)
        Rack::Utils.secure_compare(a.to_s, b.to_s)
      rescue StandardError
        false
      end

      # @api private
      # Concatenate form params per Scheme B rules:
      # - Sort by key, ASCII ascending.
      # - For repeated keys (Array values OR multiple [k,v] pairs): keep
      #   original submission order, emit ``key + value`` once per occurrence.
      # - Non-string values are stringified via ``to_s``.
      def self._sorted_concat_params(params)
        return '' if params.nil? || (params.respond_to?(:empty?) && params.empty?)

        items = []
        if params.is_a?(Hash)
          params.each do |k, v|
            if v.is_a?(Array)
              v.each { |vi| items << [k.to_s, vi] }
            else
              items << [k.to_s, v]
            end
          end
        elsif params.is_a?(Array)
          params.each do |pair|
            # Accept [k, v] pairs (the most common form).
            next unless pair.is_a?(Array) && pair.length >= 2

            items << [pair[0].to_s, pair[1]]
          end
        else
          return ''
        end

        # Stable sort by key — preserves original order within repeated keys.
        items = items.each_with_index.sort_by { |(k, _v), idx| [k, idx] }.map(&:first)

        items.map { |k, v| "#{k}#{v.nil? ? '' : v}" }.join
      end

      # @api private
      # Best-effort parse of an x-www-form-urlencoded body. Returns an
      # array of [key, value] pairs (preserving order, including duplicate
      # keys). Returns [] if the body doesn't decode as form data.
      def self._parse_form_body(raw_body)
        return [] if raw_body.nil? || raw_body.empty?

        pairs = []
        raw_body.split('&').each do |chunk|
          next if chunk.empty?

          k, _eq, v = chunk.partition('=')
          decoded_k = CGI.unescape(k)
          decoded_v = CGI.unescape(v)
          pairs << [decoded_k, decoded_v]
        end
        pairs
      rescue StandardError
        []
      end

      # @api private
      # Return the URL variants to try for Scheme B port normalization.
      #
      # - If the URL already has a non-standard port: just the input URL.
      # - If https + no port: input URL AND url with ``:443``.
      # - If http + no port: input URL AND url with ``:80``.
      # - If https + ``:443`` / http + ``:80``: input URL AND url without port.
      # - Otherwise (any explicit non-standard port): just the input URL.
      def self._candidate_urls(url)
        parsed = URI.parse(url)
        host = parsed.host
        return [url] if host.nil? || host.empty?

        scheme = (parsed.scheme || '').downcase
        standard = { 'http' => 80, 'https' => 443 }[scheme]
        port = parsed.port

        candidates = [url]

        if standard && parsed.respond_to?(:default_port) && port == parsed.default_port &&
           !_explicit_port?(url, scheme)
          # No explicit port in original URL; URI added the default.
          with_port_url = _build_url_with_port(parsed, standard)
          candidates << with_port_url if with_port_url != url
        elsif standard && port == standard && _explicit_port?(url, scheme)
          # Original URL had the standard port spelled out — also try without.
          without_port_url = _build_url_without_port(parsed)
          candidates << without_port_url if without_port_url != url
        end
        # Else: non-standard explicit port — only try as-is.

        candidates
      rescue URI::InvalidURIError
        [url]
      end

      # @api private
      # Heuristic: was a port explicitly written into the URL string?
      # ``URI`` always populates ``port`` (with the default), so we have to
      # look at the raw string.
      def self._explicit_port?(url, _scheme)
        # Look for ``:NNN`` between the host and the path / query / end.
        # Avoid false positives in ``://``, userinfo, IPv6 brackets, etc.
        no_scheme = url.sub(%r{\A[^:]+://}, '')
        no_userinfo = no_scheme.sub(/\A[^@\/?#]*@/, '')
        # Strip IPv6 zone if any: "[..]" then look after ]
        if no_userinfo.start_with?('[')
          after_bracket = no_userinfo.sub(/\A\[[^\]]*\]/, '')
          !!(after_bracket =~ /\A:\d+/)
        else
          host_and_rest = no_userinfo
          host_part, _sep, _rest = host_and_rest.partition(%r{[/?#]})
          !!(host_part =~ /:\d+\z/)
        end
      end

      # @api private
      def self._build_url_with_port(parsed, port)
        netloc_host = parsed.host.include?(':') ? "[#{parsed.host}]" : parsed.host
        prefix = "#{parsed.scheme}://"
        prefix += "#{parsed.userinfo}@" if parsed.userinfo
        rest = +''
        rest << (parsed.path || '')
        rest << "?#{parsed.query}" if parsed.query
        rest << "##{parsed.fragment}" if parsed.fragment
        "#{prefix}#{netloc_host}:#{port}#{rest}"
      end

      # @api private
      def self._build_url_without_port(parsed)
        netloc_host = parsed.host.include?(':') ? "[#{parsed.host}]" : parsed.host
        prefix = "#{parsed.scheme}://"
        prefix += "#{parsed.userinfo}@" if parsed.userinfo
        rest = +''
        rest << (parsed.path || '')
        rest << "?#{parsed.query}" if parsed.query
        rest << "##{parsed.fragment}" if parsed.fragment
        "#{prefix}#{netloc_host}#{rest}"
      end

      # @api private
      # If URL has ``?bodySHA256=<hex>``, verify ``sha256_hex(raw_body)`` matches.
      # Returns true if the param is absent (no constraint), or present and
      # matches. Returns false only when the param is present and mismatches.
      def self._check_body_sha256(url, raw_body)
        parsed = URI.parse(url)
        return true if parsed.query.nil? || parsed.query.empty?

        # Use _parse_form_body for consistency (handles repeated keys etc).
        qparams = _parse_form_body(parsed.query)
        body_hash = qparams.find { |(k, _)| k == 'bodySHA256' }
        return true if body_hash.nil?

        actual = Digest::SHA256.hexdigest(raw_body.to_s)
        _safe_eq(actual, body_hash[1])
      rescue URI::InvalidURIError
        true
      end
    end
  end
end
