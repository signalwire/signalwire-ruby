# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'base64'
require 'openssl'
require_relative 'request_options'
require_relative '../version'
require_relative '../error'

module SignalWire
  module REST
    # Raised when the SignalWire REST API returns a non-2xx response.
    #
    # +status_code+ is the HTTP status. For a TRANSPORT failure (the request
    # never reached a response — connection refused, DNS failure, connection
    # reset, TLS error) it is +nil+ and the raised type is the subclass
    # {SignalWireRestTransportError}. Callers catch this one family for every
    # REST failure, HTTP or transport.
    class SignalWireRestError < SignalWire::Error
      attr_reader :status_code, :body, :url, :method_name, :headers, :request_id

      # §6.6 error-observability: +headers+ is the response header map (or +nil+
      # for a transport error that produced no response) and +request_id+ is the
      # platform request id pulled from those headers — client-side observability
      # with NO wire-contract change. Appended to the message when present.
      # Response-id header names, in preference order, matched case-insensitively.
      REQUEST_ID_HEADERS = %w[
        x-request-id x-signalwire-request-id request-id x-amzn-requestid
      ].freeze

      def initialize(status_code, body, url, method_name = 'GET', headers: nil)
        @status_code = status_code
        @body        = body
        @url         = url
        @method_name = method_name
        @headers     = headers
        @request_id  = extract_request_id(headers)
        super(build_message)
      end

      private

      def build_message
        base = if @status_code.nil?
                 "#{@method_name} #{@url} failed to reach the server: #{@body}"
               else
                 "#{@method_name} #{@url} returned #{@status_code}: #{@body}"
               end
        @request_id ? "#{base} (request-id: #{@request_id})" : base
      end

      # Pull the platform request id from a response header map (case-insensitive),
      # preferring the SignalWire/proxy header order. Returns nil when absent.
      # Private (internal plumbing, not public API surface).
      def extract_request_id(headers)
        return nil if headers.nil? || headers.empty?

        lowered = headers.each_with_object({}) { |(k, v), h| h[k.to_s.downcase] = v }
        REQUEST_ID_HEADERS.each { |name| return lowered[name] if lowered.key?(name) }
        nil
      end
    end

    # Raised when a REST request never reached a response — a transport-level
    # failure (connection refused, DNS failure, connection reset, TLS error).
    #
    # A member of the {SignalWireRestError} family (+status_code+ is +nil+,
    # +body+ is the underlying transport error message) so a caller catching
    # +SignalWireRestError+ handles both HTTP-error and transport-error cases
    # with one +rescue+, instead of a bare +Errno::ECONNREFUSED+ / +SocketError+
    # / +Net::OpenTimeout+ leaking out of the REST client.
    class SignalWireRestTransportError < SignalWireRestError
      def initialize(body, url, method_name = 'GET')
        super(nil, body, url, method_name)
      end
    end

    # Outcome of one attempt in the REST retry loop: either DONE (carrying the
    # decoded success body) or RETRY (the loop should try again — backoff has
    # already been slept). A terminal typed error is raised directly, never
    # wrapped in an Attempt.
    class Attempt
      attr_reader :value

      def self.done(value)
        new(true, value)
      end

      def self.retry
        new(false, nil)
      end

      def initialize(done, value)
        @done  = done
        @value = value
      end

      def done?
        @done
      end
    end

    # Thin wrapper around Net::HTTP with Basic Auth and JSON handling.
    class HttpClient
      attr_reader :base_url, :project_id

      # REST client User-Agent. The product token stays stable at
      # `signalwire-ruby`; the version segment is the real SDK version so it can
      # never drift from a hardcoded literal. Mirrors the Python reference fix
      # (rest/_base.py `_user_agent`) — SDK_BUG_LEDGER P1: the old
      # `signalwire-agents-ruby-rest/1.0` was both the wrong product token and a
      # stale `/1.0` while the package was at 3.x.
      USER_AGENT = "signalwire-ruby/#{SignalWire::VERSION}".freeze

      # Transport-level failures Net::HTTP raises when the request never reaches
      # a response: connection refused / DNS failure (SocketError) / connection
      # reset / open+read timeouts / TLS handshake error / an unexpected EOF. All
      # wrap into the typed {SignalWireRestTransportError} — a member of the
      # SignalWireRestError family — so a caller catching SignalWireRestError
      # handles them too, instead of a bare exception leaking out. (SystemCallError
      # is the Errno base: ECONNREFUSED / ECONNRESET / EHOSTUNREACH / ETIMEDOUT …)
      TRANSPORT_ERRORS = [
        SocketError,
        SystemCallError,
        Net::OpenTimeout,
        Net::ReadTimeout,
        OpenSSL::SSL::SSLError,
        EOFError,
        IOError
      ].freeze

      # +base_url+ overrides the derived +https://{space}+ value when set,
      # which is how the audit fixture and tests point the client at a
      # loopback server. Pass either +space+ ("acme") / a host
      # ("acme.signalwire.com") OR an explicit +base_url+ ("http://127.0.0.1:NNNN").
      #
      # +ca_file+ (optional) names a PEM CA bundle to trust for HTTPS, for
      # private-CA / pinned-CA deployments. When set, requests verify the peer
      # (VERIFY_PEER) against a store seeded from the OpenSSL defaults (which
      # honor SSL_CERT_FILE) plus that bundle. When unset, it falls back to the
      # fleet-standard +SIGNALWIRE_REST_CA_FILE+ env var (the REST transport's
      # custom-CA trust bundle). When neither is set, Net::HTTP's default
      # verification (system store, VERIFY_PEER) applies unchanged. HTTPS is
      # always verified either way — there is no VERIFY_NONE path.
      #
      # +request_options+ (optional) is the client-default {RequestOptions}
      # envelope (timeout / retries / backoff / abort_signal) applied to every
      # request, shallow-overridden by any per-request +request_options:+.
      def initialize(project_id, token, space, request_options: nil, base_url: nil, ca_file: nil)
        @base_url        = derive_base_url(space, base_url)
        @project_id      = project_id
        @token           = token
        effective_ca    = ca_file
        effective_ca    = ENV.fetch('SIGNALWIRE_REST_CA_FILE', nil) if effective_ca.nil? || effective_ca.empty?
        @ca_file         = (effective_ca if effective_ca && !effective_ca.empty?)
        @auth_header     = "Basic #{Base64.strict_encode64("#{project_id}:#{token}")}"
        @request_options = request_options
      end

      def get(path, params = nil, request_options: nil)
        request('GET', path, params: params, request_options: request_options)
      end

      def post(path, body = nil, params: nil, request_options: nil)
        request('POST', path, body: body, params: params, request_options: request_options)
      end

      def put(path, body = nil, request_options: nil)
        request('PUT', path, body: body, request_options: request_options)
      end

      def patch(path, body = nil, request_options: nil)
        request('PATCH', path, body: body, request_options: request_options)
      end

      def delete(path, request_options: nil)
        request('DELETE', path, request_options: request_options)
      end

      private

      # An explicit +base_url+ wins (trailing slash stripped); otherwise derive
      # +https://{host}+ from +space+ ("acme" -> acme.signalwire.com; a value
      # already containing a dot is treated as a full host).
      def derive_base_url(space, base_url)
        return base_url.sub(%r{/$}, '') if base_url && !base_url.empty?

        host = space.include?('.') ? space : "#{space}.signalwire.com"
        "https://#{host}"
      end

      def request(method, path, body: nil, params: nil, request_options: nil)
        uri  = build_uri(path, params)
        opts = RequestOptions.resolve(@request_options, request_options)

        # total attempts = retries + 1; retry on a retryable status (idempotency-
        # aware) or a transport error, honoring Retry-After then exponential
        # backoff. abort_signal is checked cooperatively before every attempt.
        # D1: the error's +url+ is the FULL request URL (scheme+host+path+query),
        # the exact string that went on the wire — not the bare path. +uri+ is
        # already the composed absolute URL, so thread +uri.to_s+ to every error
        # site.
        url = uri.to_s
        attempt = 0
        loop do
          attempt += 1
          check_abort!(opts, url, method)
          result = attempt_request(method, url, uri, body, opts, attempt)
          return result.value if result.done?
          # else: a retry was scheduled (backoff already slept) — loop again.
        end
      end

      # One attempt of the retry loop. Returns an {Attempt}: +done?+ true carries
      # the final +value+ (success body) or has already raised the terminal typed
      # error; +done?+ false means "retry scheduled, loop again". Keeps +request+
      # a thin driver so the retry policy reads linearly. +url+ is the full
      # request URL stored in any raised error (D1).
      def attempt_request(method, url, uri, body, opts, attempt)
        response = perform(method, uri, body, opts.timeout)
        handle_http_response(response, url, method, opts, attempt)
      rescue *TRANSPORT_ERRORS => e
        # Transport failure (connection refused / DNS / reset / TLS / timeout):
        # the request never produced a response. Retry if attempts remain, else
        # wrap in the typed error family.
        return Attempt.retry if retry_transport?(opts, attempt)

        raise SignalWireRestTransportError.new(e.message, url, method)
      end

      # abort_signal is checked cooperatively BEFORE each attempt: a set signal
      # surfaces as the transport-error family (no response was produced), not a
      # bare exception.
      def check_abort!(opts, url, method)
        return unless opts.abort_signal&.set?

        raise SignalWireRestTransportError.new('request cancelled by abort_signal', url, method)
      end

      def retry_transport?(opts, attempt)
        return false unless attempt <= opts.retries

        sleep_backoff(opts.retry_backoff * (2**(attempt - 1)))
        true
      end

      # Reduce a completed HTTP response to an {Attempt}: schedule a retry for a
      # retryable non-2xx (idempotency-aware) with attempts remaining, raise the
      # terminal typed error for a non-retryable/exhausted non-2xx, else return
      # the decoded success body.
      def handle_http_response(response, url, method, opts, attempt)
        return handle_error_response(response, url, method, opts, attempt) unless response.is_a?(Net::HTTPSuccess)

        return Attempt.done({}) if response.code.to_i == 204 || response.body.nil? || response.body.empty?

        Attempt.done(JSON.parse(response.body))
      end

      # A non-2xx response: retry if it's a retryable status with attempts left
      # (idempotency-aware), else raise the terminal typed error. +url+ is the
      # full request URL stored in the error (D1).
      def handle_error_response(response, url, method, opts, attempt)
        status = response.code.to_i
        if attempt <= opts.retries && opts.status_retryable?(method, status)
          delay = retry_after_seconds(response) || (opts.retry_backoff * (2**(attempt - 1)))
          sleep_backoff(delay)
          return Attempt.retry
        end
        raise SignalWireRestError.new(status, parse_error_body(response), url, method,
                                      headers: response_headers(response))
      end

      # Flatten a Net::HTTPResponse's headers into a plain {name => value} hash
      # (§6.6) so the raised error can expose them + the platform request id.
      def response_headers(response)
        headers = {}
        response.each_header { |name, value| headers[name] = value }
        headers
      end

      # Issue one HTTP attempt. Net::HTTP's +read_timeout+/+open_timeout+ bound
      # the per-attempt wall clock; on exceed it raises Net::ReadTimeout/
      # Net::OpenTimeout (in TRANSPORT_ERRORS), which the request loop wraps.
      def perform(method, uri, body, timeout)
        req = build_request(method, uri)
        apply_headers(req)
        req.body = JSON.generate(body) if body && %w[POST PUT PATCH].include?(method)
        build_http(uri, timeout).request(req)
      end

      # Build the Net::HTTP transport for one attempt: TLS when https, the
      # per-attempt timeout, and max_retries=0 (Net::HTTP silently retries an
      # idempotent request once by default on a timeout/reset — that would both
      # double-count attempts against our own retry loop and swallow a timeout by
      # succeeding on the hidden retry; this client's request loop is the sole
      # retry authority).
      def build_http(uri, timeout)
        http = Net::HTTP.new(uri.host, uri.port)
        configure_ssl(http) if uri.scheme == 'https'
        if timeout
          http.open_timeout = timeout
          http.read_timeout = timeout
        end
        http.max_retries = 0
        http
      end

      # Backoff sleep between retries. A tiny seam kept separate so the intent is
      # explicit; a zero/negative delay (the tests pass retry_backoff 0) is a
      # no-op so the suite never waits on wall-clock.
      def sleep_backoff(seconds)
        sleep(seconds) if seconds&.positive?
      end

      # Parse a +Retry-After+ header (delta-seconds form) if present; nil for an
      # HTTP-date form or when absent (the caller falls back to computed backoff).
      def retry_after_seconds(response)
        value = response['Retry-After']
        return nil if value.nil?

        Float(value)
      rescue ArgumentError, TypeError
        nil
      end

      def build_uri(path, params)
        uri = URI("#{@base_url}#{path}")
        uri.query = URI.encode_www_form(params) if params && !params.empty?
        uri
      end

      def build_request(method, uri)
        klass = {
          'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post, 'PUT' => Net::HTTP::Put,
          'PATCH' => Net::HTTP::Patch, 'DELETE' => Net::HTTP::Delete
        }[method]
        raise ArgumentError, "Unknown HTTP method: #{method}" unless klass

        klass.new(uri)
      end

      def apply_headers(req)
        req['Authorization'] = @auth_header
        req['Content-Type']  = 'application/json'
        req['Accept']        = 'application/json'
        req['User-Agent']    = USER_AGENT
      end

      def configure_ssl(http)
        http.use_ssl = true
        # Always verify the server certificate. When an explicit CA bundle
        # was supplied, trust it in addition to the OpenSSL defaults (which
        # honor SSL_CERT_FILE); otherwise fall back to Net::HTTP's default
        # store. Never VERIFY_NONE.
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        return unless @ca_file

        require 'openssl'
        store = OpenSSL::X509::Store.new
        store.set_default_paths
        store.add_file(@ca_file) if File.file?(@ca_file)
        http.cert_store = store
      end

      def parse_error_body(response)
        JSON.parse(response.body)
      rescue StandardError
        response.body
      end
    end

    # Base for all namespace/resource classes.
    class BaseResource
      def initialize(http, base_path)
        @http      = http
        @base_path = base_path
      end

      private

      def _path(*parts)
        ([@base_path] + parts.map(&:to_s)).join('/')
      end
    end

    # Read-only resource with get/list. Mirrors Python's
    # +signalwire.rest._base.ReadResource+: the read half of the CRUD surface,
    # extended by CrudResource with create/update/delete.
    class ReadResource < BaseResource
      def list(**params)
        @http.get(@base_path, params.empty? ? nil : params)
      end

      # Iterate every item across all pages of this resource's list endpoint.
      #
      # +list+ returns a single raw page (the server's first response). For
      # endpoints that paginate on the wire (a +links.next+ / +page_token+ in
      # the response), +paginate+ follows those links and yields each item:
      #
      #   client.fabric.addresses.paginate.each { |address| ... }
      #
      # Wires the resource layer to the tested +PaginatedIterator+ (which walks
      # +resp["data"]+ and follows +resp["links"]["next"]+), so callers no
      # longer hand-construct the path + token loop. Returns an Enumerable
      # +PaginatedIterator+ — the Ruby idiom for Python's returned iterator.
      def paginate(**params)
        PaginatedIterator.new(@http, @base_path, params.empty? ? nil : params, 'data')
      end

      def get(resource_id)
        @http.get(_path(resource_id))
      end
    end

    # Standard CRUD resource: ReadResource (get/list) + create/update/delete.
    class CrudResource < ReadResource
      # @update_method is a class-INSTANCE variable, which Ruby subclasses do NOT
      # inherit. FabricResourcePUT sets it to 'PUT', but its subclasses
      # (CallFlowsResource, ConferenceRoomsResource, CxmlApplicationsResource,
      # SubscribersResource) would otherwise fall back to 'PATCH' and send the
      # wrong verb to PUT-only routes. Walk the ancestor chain so the nearest
      # ancestor that set it wins — mirroring Python's inherited class attribute
      # `_update_method`.
      def self.update_method
        return @update_method if defined?(@update_method) && @update_method

        if superclass.respond_to?(:update_method)
          superclass.update_method
        else
          'PATCH'
        end
      end

      class << self
        attr_writer :update_method
      end

      def create(**kwargs)
        @http.post(@base_path, kwargs)
      end

      def update(resource_id, **kwargs)
        m = self.class.update_method.downcase
        @http.send(m, _path(resource_id), kwargs)
      end

      def delete(resource_id)
        @http.delete(_path(resource_id))
      end
    end

    # CRUD resource that also supports listing the addresses bound to a
    # resource. Mirrors Python's +signalwire.rest._base.CrudWithAddresses+:
    # it adds a single +list_addresses+ helper on top of the standard
    # list/create/get/update/delete surface, issuing
    # +GET {base_path}/{resource_id}/addresses+.
    class CrudWithAddresses < CrudResource
      def list_addresses(resource_id, **params)
        @http.get(_path(resource_id, 'addresses'), params.empty? ? nil : params)
      end
    end
  end
end
