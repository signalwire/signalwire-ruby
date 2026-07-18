# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'base64'
require 'openssl'

module SignalWire
  module REST
    # Raised when the SignalWire REST API returns a non-2xx response.
    #
    # +status_code+ is the HTTP status. For a TRANSPORT failure (the request
    # never reached a response — connection refused, DNS failure, connection
    # reset, TLS error) it is +nil+ and the raised type is the subclass
    # {SignalWireRestTransportError}. Callers catch this one family for every
    # REST failure, HTTP or transport.
    class SignalWireRestError < StandardError
      attr_reader :status_code, :body, :url, :method_name

      def initialize(status_code, body, url, method_name = 'GET')
        @status_code = status_code
        @body        = body
        @url         = url
        @method_name = method_name
        message = if status_code.nil?
                    "#{method_name} #{url} failed to reach the server: #{body}"
                  else
                    "#{method_name} #{url} returned #{status_code}: #{body}"
                  end
        super(message)
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

    # Thin wrapper around Net::HTTP with Basic Auth and JSON handling.
    class HttpClient
      attr_reader :base_url, :project_id

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
      # honor SSL_CERT_FILE) plus that bundle. When unset, Net::HTTP's default
      # verification (system store, VERIFY_PEER) applies unchanged. HTTPS is
      # always verified either way — there is no VERIFY_NONE path.
      def initialize(project_id, token, space, base_url: nil, ca_file: nil)
        if base_url && !base_url.empty?
          @base_url = base_url.sub(%r{/$}, '')
        else
          host       = space.include?('.') ? space : "#{space}.signalwire.com"
          @base_url  = "https://#{host}"
        end
        @project_id  = project_id
        @token       = token
        @ca_file     = (ca_file if ca_file && !ca_file.empty?)
        @auth_header = "Basic #{Base64.strict_encode64("#{project_id}:#{token}")}"
      end

      def get(path, params = nil)
        request('GET', path, params: params)
      end

      def post(path, body = nil, params: nil)
        request('POST', path, body: body, params: params)
      end

      def put(path, body = nil)
        request('PUT', path, body: body)
      end

      def patch(path, body = nil)
        request('PATCH', path, body: body)
      end

      def delete(path)
        request('DELETE', path)
      end

      private

      def request(method, path, body: nil, params: nil)
        uri = build_uri(path, params)
        req = build_request(method, uri)
        apply_headers(req)
        req.body = JSON.generate(body) if body && %w[POST PUT PATCH].include?(method)

        http = Net::HTTP.new(uri.host, uri.port)
        configure_ssl(http) if uri.scheme == 'https'

        handle_response(send_request(http, req, path, method), path, method)
      end

      # Issue the request, wrapping any transport-level failure (the request
      # never produced a response: connection refused / DNS / reset / TLS /
      # timeout) in the typed {SignalWireRestTransportError} so a caller catching
      # SignalWireRestError handles it too, instead of a bare
      # Errno::ECONNREFUSED / SocketError leaking out.
      def send_request(http, req, path, method)
        http.request(req)
      rescue *TRANSPORT_ERRORS => e
        raise SignalWireRestTransportError.new(e.message, path, method)
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
        req['User-Agent']    = 'signalwire-agents-ruby-rest/1.0'
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

      def handle_response(response, path, method)
        unless response.is_a?(Net::HTTPSuccess)
          raise SignalWireRestError.new(response.code.to_i, parse_error_body(response), path, method)
        end

        return {} if response.code.to_i == 204 || response.body.nil? || response.body.empty?

        JSON.parse(response.body)
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
