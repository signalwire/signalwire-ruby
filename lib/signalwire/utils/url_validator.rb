# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'ipaddr'
require 'net/http'
require 'resolv'
require 'uri'

require_relative '../logging'
require_relative '../security/security_utils'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Utils — small shared helpers with no dependency on the agent surface.
  module Utils
    # SSRF-prevention guard for user-supplied URLs.
    #
    # {.validate_url} rejects non-http(s) schemes, missing hostnames, and any
    # URL whose hostname resolves to a private / loopback / link-local /
    # cloud-metadata IP.  When +allow_private+ is true, OR the
    # +SWML_ALLOW_PRIVATE_URLS+ env var is set to "1", "true" or "yes"
    # (case-insensitive), the IP-blocklist check is skipped.
    module UrlValidator
      # SSRF block list, checked in this order.
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
      # hermetic; production calls Resolv.getaddresses. The underscore prefix
      # keeps it out of the public surface inventory — {.validate_url} is the
      # only public entry point on this module.
      def self._resolver
        @_resolver
      end

      # @api private — override the DNS resolver, so tests can drive
      # {.validate_url} without real name resolution. Not part of the public surface.
      def self._resolver=(value)
        @_resolver = value
      end

      # Validate that a URL is safe to fetch.
      #
      # @param url [String] URL to validate
      # @param allow_private [Boolean] when true, bypass the IP-blocklist check
      # @return [Boolean] true if the URL is safe to fetch
      # +allow_private+ is a positional boolean (defaulting to false) rather
      # than a keyword, to keep the public method signature stable.
      def self.validate_url(url, allow_private = false)
        parsed = URI.parse(url)
        return false unless _valid_scheme?(parsed)

        hostname = _extract_hostname(parsed)
        return false if hostname.nil?

        return true if allow_private || _env_allows_private?

        _hostname_safe?(hostname)
      rescue URI::InvalidURIError, IPAddr::InvalidAddressError => e
        LOG.warn("URL validation error: #{e.message}")
        false
      end

      # @api private — only `http` and `https` are allowed. Rejecting everything else
      # is what stops `file:`, `gopher:` and friends from reaching the fetcher.
      #
      # @return [Boolean]
      def self._valid_scheme?(parsed)
        scheme = (parsed.scheme || '').downcase
        return true if %w[http https].include?(scheme)

        LOG.warn("URL rejected: invalid scheme #{parsed.scheme}")
        false
      end
      private_class_method :_valid_scheme?

      # @return [String, nil] the bracket-stripped hostname, or nil if absent.
      def self._extract_hostname(parsed)
        hostname = parsed.host
        if hostname.nil? || hostname.empty?
          LOG.warn('URL rejected: no hostname')
          return nil
        end

        # URI keeps brackets in host for IPv6 literals; strip them.
        return hostname[1..-2] if hostname.start_with?('[') && hostname.end_with?(']')

        hostname
      end
      private_class_method :_extract_hostname

      # @return [Boolean] false if the hostname can't resolve or any resolved
      #   IP falls inside a blocked network.
      def self._hostname_safe?(hostname)
        ips = _resolve(hostname)
        if ips.nil? || ips.empty?
          LOG.warn("URL rejected: could not resolve hostname #{hostname}")
          return false
        end

        ips.none? { |ip_str| _ip_blocked?(hostname, ip_str) }
      end
      private_class_method :_hostname_safe?

      # @api private — whether a resolved IP falls in one of the BLOCKED_NETWORKS
      # (loopback, link-local, private ranges). This is the SSRF check itself: it
      # runs on the RESOLVED address, so a public hostname pointing at an internal
      # IP is still rejected.
      #
      # @return [Boolean]
      def self._ip_blocked?(hostname, ip_str)
        ip = _parse_ip(ip_str)
        return false if ip.nil?

        BLOCKED_NETWORKS.any? do |cidr|
          next false unless IPAddr.new(cidr).include?(ip)

          LOG.warn("URL rejected: #{hostname} resolves to blocked IP #{ip_str} (in #{cidr})")
          true
        end
      end
      private_class_method :_ip_blocked?

      # @api private — parse an address string, yielding nil rather than raising for
      # an unparseable value.
      #
      # @return [IPAddr, nil]
      def self._parse_ip(ip_str)
        IPAddr.new(ip_str)
      rescue IPAddr::InvalidAddressError
        nil
      end
      private_class_method :_parse_ip

      # @api private — whether `SWML_ALLOW_PRIVATE_URLS` is set to 1/true/yes, the
      # explicit opt-out that lets a deployment reach private addresses.
      #
      # @return [Boolean]
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

      # @api private — the first resolved address of +hostname+ outside the
      # blocked networks, or nil.
      def self._public_address(hostname)
        (_resolve(hostname) || []).find { |ip| !_ip_blocked?(hostname, ip) }
      end

      # Raised by {PublicSession} for a private, internal or invalid URL.
      class BlockedURLError < StandardError; end

      # @api private — an HTTP session for fetching user-supplied URLs.
      #
      # Checking a URL with {UrlValidator.validate_url} before fetching it is not
      # enough on its own: the server can redirect to an internal address, and
      # the hostname can resolve differently when the connection is made. This
      # session checks the URL of every request it sends, redirects included,
      # and connects to the address it validated (so a re-resolution cannot
      # land on a blocked one). +SWML_ALLOW_PRIVATE_URLS+ turns both checks off,
      # as it does for {UrlValidator.validate_url}.
      class PublicSession
        # Redirects followed in one fetch.
        MAX_REDIRECTS = 10

        # @return [Hash{String=>String}] headers sent with every request
        attr_reader :headers

        # @param allow_private [Boolean] when true, skip the address checks
        def initialize(allow_private: false)
          @allow_private = allow_private
          @headers = {}
        end

        # GET +url+, following up to {MAX_REDIRECTS} redirects, each one checked.
        #
        # @param url [String]
        # @param timeout [Numeric] per-request open/read timeout in seconds
        # @return [Net::HTTPResponse] the final response
        # @raise [BlockedURLError] for a private, internal or invalid URL (or hop)
        def get(url, timeout: 5)
          MAX_REDIRECTS.times do
            response = request_once(url, timeout)
            return response unless response.is_a?(Net::HTTPRedirection) && response['location']

            url = URI.join(url, response['location']).to_s
          end
          raise BlockedURLError, "Too many redirects fetching #{SignalWire::Security::SecurityUtils.redact_url(url)}"
        end

        # Nothing to release: each request opens its own connection.
        #
        # @return [nil]
        def close
          nil
        end

        private

        def private_allowed?
          @allow_private || UrlValidator.send(:_env_allows_private?)
        end

        def request_once(url, timeout)
          unless UrlValidator.validate_url(url, @allow_private)
            raise BlockedURLError, "URL rejected: #{SignalWire::Security::SecurityUtils.redact_url(url)} " \
                                   'is private, internal or invalid'
          end

          uri = URI(url)
          http = connection(uri, timeout)
          request = Net::HTTP::Get.new(uri)
          @headers.each { |name, value| request[name] = value }
          http.request(request)
        end

        def connection(uri, timeout)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == 'https'
          http.open_timeout = timeout
          http.read_timeout = timeout
          # Connect to the validated address, so the peer check applies.
          http.ipaddr = UrlValidator.send(:_public_address, uri.hostname) unless private_allowed?
          http
        end
      end
    end
  end
end
