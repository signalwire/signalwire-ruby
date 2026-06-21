# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'base64'
require 'openssl'

module SignalWire
  module REST
    # Raised when the SignalWire REST API returns a non-2xx response.
    class SignalWireRestError < StandardError
      attr_reader :status_code, :body, :url, :method_name

      def initialize(status_code, body, url, method_name = 'GET')
        @status_code = status_code
        @body        = body
        @url         = url
        @method_name = method_name
        super("#{method_name} #{url} returned #{status_code}: #{body}")
      end
    end

    # Thin wrapper around Net::HTTP with Basic Auth and JSON handling.
    class HttpClient
      attr_reader :base_url, :project_id

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
        _request('GET', path, params: params)
      end

      def post(path, body = nil, params: nil)
        _request('POST', path, body: body, params: params)
      end

      def put(path, body = nil)
        _request('PUT', path, body: body)
      end

      def patch(path, body = nil)
        _request('PATCH', path, body: body)
      end

      def delete(path)
        _request('DELETE', path)
      end

      private

      def _request(method, path, body: nil, params: nil)
        uri = _build_uri(path, params)
        req = _build_request(method, uri)
        _apply_headers(req)
        req.body = JSON.generate(body) if body && %w[POST PUT PATCH].include?(method)

        http = Net::HTTP.new(uri.host, uri.port)
        _configure_ssl(http) if uri.scheme == 'https'

        _handle_response(http.request(req), path, method)
      end

      def _build_uri(path, params)
        uri = URI("#{@base_url}#{path}")
        uri.query = URI.encode_www_form(params) if params && !params.empty?
        uri
      end

      def _build_request(method, uri)
        klass = {
          'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post, 'PUT' => Net::HTTP::Put,
          'PATCH' => Net::HTTP::Patch, 'DELETE' => Net::HTTP::Delete
        }[method]
        raise ArgumentError, "Unknown HTTP method: #{method}" unless klass

        klass.new(uri)
      end

      def _apply_headers(req)
        req['Authorization'] = @auth_header
        req['Content-Type']  = 'application/json'
        req['Accept']        = 'application/json'
        req['User-Agent']    = 'signalwire-agents-ruby-rest/1.0'
      end

      def _configure_ssl(http)
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

      def _handle_response(response, path, method)
        unless response.is_a?(Net::HTTPSuccess)
          raise SignalWireRestError.new(response.code.to_i, _parse_error_body(response), path, method)
        end

        return {} if response.code.to_i == 204 || response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      end

      def _parse_error_body(response)
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

    # Standard CRUD resource with list/create/get/update/delete.
    class CrudResource < BaseResource
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

      def list(**params)
        @http.get(@base_path, params.empty? ? nil : params)
      end

      def create(**kwargs)
        @http.post(@base_path, kwargs)
      end

      def get(resource_id)
        @http.get(_path(resource_id))
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
