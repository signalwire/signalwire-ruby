# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'ipaddr'
require 'resolv'
require 'uri'

require_relative '../logging'

module SignalWire
  module Utils
    # SSRF-prevention guard for user-supplied URLs.
    #
    # Mirrors Python's signalwire.utils.url_validator.validate_url:
    # rejects non-http(s) schemes, missing hostnames, and any URL whose
    # hostname resolves to a private / loopback / link-local / cloud-
    # metadata IP.  When +allow_private+ is true, OR the
    # +SWML_ALLOW_PRIVATE_URLS+ env var is set to "1", "true" or "yes"
    # (case-insensitive), the IP-blocklist check is skipped.
    #
    # The method UrlValidator.validate_url projects onto the Python free
    # function signalwire.utils.url_validator.validate_url via
    # scripts/enumerate_signatures.py.
    module UrlValidator
      # Cross-port SSRF block list.  Order matches the Python reference.
      BLOCKED_NETWORKS = %w[
        10.0.0.0/8
        172.16.0.0/12
        192.168.0.0/16
        127.0.0.0/8
        169.254.0.0/16
        0.0.0.0/8
        ::1/128
        fc00::/7
        fe80::/10
      ].freeze

      LOG = SignalWire::Logging.logger('signalwire.url_validator')

      # Pluggable resolver hook. Tests inject a lambda to keep the suite
      # hermetic; production calls Resolv.getaddresses. Underscore prefix
      # keeps it out of the public surface inventory — the Python
      # reference only exposes ``validate_url`` at this module level.
      def self._resolver
        @_resolver
      end

      def self._resolver=(value)
        @_resolver = value
      end

      # Validate that a URL is safe to fetch.
      #
      # @param url [String] URL to validate
      # @param allow_private [Boolean] when true, bypass the IP-blocklist check
      # @return [Boolean] true if the URL is safe to fetch
      def self.validate_url(url, allow_private = false)
        parsed = URI.parse(url)

        scheme = (parsed.scheme || '').downcase
        unless %w[http https].include?(scheme)
          LOG.warn("URL rejected: invalid scheme #{parsed.scheme}")
          return false
        end

        hostname = parsed.host
        if hostname.nil? || hostname.empty?
          LOG.warn('URL rejected: no hostname')
          return false
        end

        # URI keeps brackets in host for IPv6 literals; strip them.
        hostname = hostname[1..-2] if hostname.start_with?('[') && hostname.end_with?(']')

        return true if allow_private || _env_allows_private?

        ips = _resolve(hostname)
        if ips.nil? || ips.empty?
          LOG.warn("URL rejected: could not resolve hostname #{hostname}")
          return false
        end

        ips.each do |ip_str|
          ip = begin
            IPAddr.new(ip_str)
          rescue IPAddr::InvalidAddressError
            next
          end
          BLOCKED_NETWORKS.each do |cidr|
            net = IPAddr.new(cidr)
            if net.include?(ip)
              LOG.warn("URL rejected: #{hostname} resolves to blocked IP #{ip_str} (in #{cidr})")
              return false
            end
          end
        end

        true
      rescue URI::InvalidURIError, IPAddr::InvalidAddressError => e
        LOG.warn("URL validation error: #{e.message}")
        false
      end

      def self._env_allows_private?
        v = (ENV['SWML_ALLOW_PRIVATE_URLS'] || '').downcase
        %w[1 true yes].include?(v)
      end
      private_class_method :_env_allows_private?

      # @param hostname [String]
      # @return [Array<String>, nil]
      def self._resolve(hostname)
        return _resolver.call(hostname) if _resolver

        # Literal IP shortcut (covers tests that pass IP-as-hostname URLs).
        begin
          IPAddr.new(hostname)
          return [hostname]
        rescue IPAddr::InvalidAddressError
          # not a literal IP — fall through to DNS
        end
        Resolv.getaddresses(hostname)
      rescue StandardError
        nil
      end
      private_class_method :_resolve
    end
  end
end
