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
    # digest with bodySHA256 fallback) of the SignalWire webhook signing
    # scheme are tried by the combined entry point.
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
      #   see the URL reconstruction rules of the SignalWire webhook signing
      #   scheme.
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
        _scheme_b_match?(signing_key, signature, url.to_s, raw_body)
      end

      # @api private — Scheme B across URL/param-shape variants; honors bodySHA256.
      def self._scheme_b_match?(signing_key, signature, url, raw_body)
        param_shapes = [_parse_form_body(raw_body), []]
        _candidate_urls(url).each do |candidate_url|
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

        # Pre-parsed form params → Scheme B only.
        params = _coerce_form_params(params_or_raw_body)
        _scheme_b_params_match?(signing_key, signature, url.to_s, params)
      end

      # @api private — coerce non-String overload arg to Hash/Array (else TypeError).
      def self._coerce_form_params(value)
        return [] if value.nil?
        return value if value.is_a?(Hash) || value.is_a?(Array)

        raise TypeError,
              'params_or_raw_body must be a String (raw body) or a Hash/Array of form params'
      end

      # @api private — Scheme B over pre-parsed form params (no bodySHA256 check).
      def self._scheme_b_params_match?(signing_key, signature, url, params)
        concat = _sorted_concat_params(params)
        _candidate_urls(url).each do |candidate_url|
          expected_b = _b64_hmac_sha1(signing_key, candidate_url + concat)
          return true if _safe_eq(expected_b, signature)
        end
        false
      end

      # ----------------------------------------------------------------------
      # Internal helpers (underscore-prefixed: not part of the public surface).
      # ----------------------------------------------------------------------

      # @api private — case-insensitive lookup of the SignalWire (or legacy
      # Twilio-compat) signature header out of a plain header Hash. Shared with
      # the decomposed WebhookMiddleware.validate core.
      def self._signature_from_headers(headers)
        return nil unless headers.respond_to?(:each)

        lower = {}
        headers.each { |k, v| lower[k.to_s.downcase] = v }
        sig = lower['x-signalwire-signature']
        sig = lower['x-twilio-signature'] if sig.nil? || sig.to_s.empty?
        sig&.to_s
      end

      # @api private — the canonical 403 rejection triple (no body detail).
      # Shared with the decomposed WebhookMiddleware.validate core.
      def self._forbidden_triple
        [403, { 'content-type' => 'text/plain' }, ['']]
      end

      def self._hex_hmac_sha1(key, message) = OpenSSL::HMAC.hexdigest('SHA1', key.to_s, message.to_s)

      def self._b64_hmac_sha1(key, message)
        Base64.strict_encode64(OpenSSL::HMAC.digest('SHA1', key.to_s, message.to_s))
      end

      # @api private — constant-time compare; false on any error (never raises).
      def self._safe_eq(lhs, rhs)
        Rack::Utils.secure_compare(lhs.to_s, rhs.to_s)
      rescue StandardError
        false
      end

      # @api private — Scheme B concat: sort by key (ASCII), stable within
      # repeated keys, emit ``key + value`` per occurrence (nil/non-string via to_s).
      def self._sorted_concat_params(params)
        items = _concat_items(params)
        return '' if items.nil? || items.empty?

        # Stable sort by key — preserves original order within repeated keys.
        items = items.each_with_index.sort_by { |(k, _v), idx| [k, idx] }.map(&:first)
        items.map { |pair| _concat_pair(pair) }.join
      end

      def self._concat_pair((key, value)) = "#{key}#{value unless value.nil?}"

      # @api private — normalize Hash / Array-of-pairs into [key, value] items;
      # nil for unsupported shapes.
      def self._concat_items(params)
        return _hash_items(params) if params.is_a?(Hash)
        return _pair_items(params) if params.is_a?(Array)

        nil
      end

      def self._hash_items(params)
        params.flat_map do |k, v|
          v.is_a?(Array) ? v.map { |vi| [k.to_s, vi] } : [[k.to_s, v]]
        end
      end

      def self._pair_items(params)
        # Accept [k, v] pairs (the most common form).
        params.select { |pair| pair.is_a?(Array) && pair.length >= 2 }
              .map { |pair| [pair[0].to_s, pair[1]] }
      end

      # @api private — best-effort x-www-form-urlencoded parse into ordered
      # [key, value] pairs (dups kept); [] if it doesn't decode as form data.
      def self._parse_form_body(raw_body)
        return [] if raw_body.nil? || raw_body.empty?

        raw_body.split('&').reject(&:empty?).map do |chunk|
          k, _eq, v = chunk.partition('=')
          [CGI.unescape(k), CGI.unescape(v)]
        end
      rescue StandardError
        []
      end

      # @api private — URL variants to try for Scheme B port normalization:
      # add the standard port when omitted / drop it when spelled out; otherwise
      # (non-standard explicit port) just the input URL.
      def self._candidate_urls(url)
        parsed = URI.parse(url)
        host = parsed.host
        return [url] if host.nil? || host.empty?

        candidates = [url]
        variant = _port_variant_url(url, parsed)
        candidates << variant if variant && variant != url
        candidates
      rescue URI::InvalidURIError
        [url]
      end

      # @api private — alternate URL: add standard port if omitted, drop it if
      # spelled out; nil when no port normalization applies.
      def self._port_variant_url(url, parsed)
        scheme = (parsed.scheme || '').downcase
        standard = { 'http' => 80, 'https' => 443 }[scheme]
        return nil unless standard

        explicit = _explicit_port?(url, scheme)
        if _implicit_default_port?(parsed) && !explicit
          # No explicit port in original URL; URI added the default.
          _build_url(parsed, port: standard)
        elsif parsed.port == standard && explicit
          # Original URL had the standard port spelled out — also try without.
          _build_url(parsed, port: nil)
        end
        # Else: non-standard explicit port — only try as-is (nil).
      end

      def self._implicit_default_port?(parsed)
        parsed.respond_to?(:default_port) && parsed.port == parsed.default_port
      end

      # @api private
      # Heuristic: was a port explicitly written into the URL string?
      # ``URI`` always populates ``port`` (with the default), so we have to
      # look at the raw string.
      def self._explicit_port?(url, _scheme)
        # Look for ``:NNN`` between host and path/query/end, avoiding false
        # positives in ``://``, userinfo, and IPv6 brackets.
        no_userinfo = url.sub(%r{\A[^:]+://}, '').sub(%r{\A[^@/?#]*@}, '')
        if no_userinfo.start_with?('[')
          after_bracket = no_userinfo.sub(/\A\[[^\]]*\]/, '')
          !!(after_bracket =~ /\A:\d+/)
        else
          host_part, = no_userinfo.partition(%r{[/?#]})
          !!(host_part =~ /:\d+\z/)
        end
      end

      # Reassemble a URL from its parsed parts, optionally injecting a port.
      def self._build_url(parsed, port:)
        netloc_host = parsed.host.include?(':') ? "[#{parsed.host}]" : parsed.host
        userinfo = parsed.userinfo ? "#{parsed.userinfo}@" : ''
        port_part = port ? ":#{port}" : ''
        "#{parsed.scheme}://#{userinfo}#{netloc_host}#{port_part}#{_build_url_rest(parsed)}"
      end

      def self._build_url_rest(parsed)
        rest = +(parsed.path || '')
        rest << "?#{parsed.query}" if parsed.query
        rest << "##{parsed.fragment}" if parsed.fragment
        rest
      end

      # @api private — if URL has ``?bodySHA256=<hex>``, require sha256(body) to
      # match; true when the param is absent or matches, false only on mismatch.
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
