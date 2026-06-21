# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.
#
# Standalone security hygiene utilities.
#
# These mirror the TypeScript SDK's ``SecurityUtils`` (filterSensitiveHeaders,
# redactUrl, isValidHostname) and the Python reference's
# ``signalwire.core.security.security_utils`` free functions, so the same
# protections -- keeping credentials out of user callbacks and logs, reusable
# hostname validation -- are available in every port.

module SignalWire
  module Security
    # Stateless security hygiene helpers exposed as module functions.
    #
    # The three public entry points project onto the Python free functions
    # ``signalwire.core.security.security_utils.{filter_sensitive_headers,
    # redact_url, is_valid_hostname}`` via the Ruby->Python module override in
    # scripts/enumerate_surface.rb + scripts/enumerate_signatures.py. The
    # ``SENSITIVE_HEADERS`` set + regexes are internal (not on the public
    # surface; the Python reference doesn't export them either).
    module SecurityUtils
      # Header names whose values are credentials/secrets and must never be
      # handed to user callbacks or written to logs. Compared case-insensitively.
      SENSITIVE_HEADERS = %w[
        authorization
        cookie
        x-api-key
        proxy-authorization
        set-cookie
      ].freeze

      # url credentials: ``://user:secret@host`` -> ``://user:****@host``.
      URL_CREDENTIALS_RE = %r{://([^:@/]+):([^@/]+)@}

      # Hostnames must not contain whitespace, slashes, or control characters.
      HOSTNAME_REJECT_RE = %r{[\s/\\\x00-\x1f\x7f]}

      private_constant :SENSITIVE_HEADERS, :URL_CREDENTIALS_RE, :HOSTNAME_REJECT_RE

      # Return a copy of +headers+ with sensitive (credential-bearing) headers
      # removed, so request headers can be safely passed to user callbacks.
      #
      # @param headers [Hash, nil] Mapping of header name -> value.
      # @return [Hash] A new hash containing only the non-sensitive headers
      #   (keys preserved as given; the sensitivity check is case-insensitive).
      def self.filter_sensitive_headers(headers)
        return {} if headers.nil? || headers.empty?

        headers.reject { |k, _v| SENSITIVE_HEADERS.include?(k.to_s.downcase) }
      end

      # Mask the password in a URL's userinfo before logging.
      #
      # ``https://user:secret@host/path`` -> ``https://user:****@host/path``.
      # A URL with no embedded credentials is returned unchanged.
      #
      # @param url [String] The URL string (non-strings are returned as-is).
      # @return [String] The URL with any ``:password@`` replaced by ``:****@``.
      def self.redact_url(url)
        return url unless url.is_a?(String)

        url.gsub(URL_CREDENTIALS_RE, '://\1:****@')
      end

      # Standalone hostname sanity check: reject empty hosts and any host
      # containing whitespace, slashes, or control characters.
      #
      # This is the reusable character-level check, independent of the full
      # SignalWire::Utils::UrlValidator.validate_url (which also does scheme
      # checks, DNS resolution, and private-IP blocking). Callers that only
      # need to validate a hostname string use this.
      #
      # @param host [String, nil] The hostname string.
      # @return [Boolean] true if the hostname is non-empty and contains no
      #   whitespace/slashes/control characters; false otherwise.
      def self.is_valid_hostname(host)
        return false if host.nil? || host.empty?

        !HOSTNAME_REJECT_RE.match?(host)
      end
    end
  end
end
