# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'base64'

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
      attr_reader :base_url

      def initialize(project_id, token, space)
        host = space.include?('.') ? space : "#{space}.signalwire.com"
        @base_url    = "https://#{host}"
        @project_id  = project_id
        @token       = token
        @auth_header = 'Basic ' + Base64.strict_encode64("#{project_id}:#{token}")
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
        uri = URI("#{@base_url}#{path}")
        if params && !params.empty?
          uri.query = URI.encode_www_form(params)
        end

        req = case method
              when 'GET'    then Net::HTTP::Get.new(uri)
              when 'POST'   then Net::HTTP::Post.new(uri)
              when 'PUT'    then Net::HTTP::Put.new(uri)
              when 'PATCH'  then Net::HTTP::Patch.new(uri)
              when 'DELETE' then Net::HTTP::Delete.new(uri)
              else raise ArgumentError, "Unknown HTTP method: #{method}"
              end

        req['Authorization'] = @auth_header
        req['Content-Type']  = 'application/json'
        req['Accept']        = 'application/json'
        req['User-Agent']    = 'signalwire-agents-ruby-rest/1.0'

        if body && %w[POST PUT PATCH].include?(method)
          req.body = JSON.generate(body)
        end

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        response = http.request(req)

        unless response.is_a?(Net::HTTPSuccess)
          err_body = begin
                       JSON.parse(response.body)
                     rescue
                       response.body
                     end
          raise SignalWireRestError.new(response.code.to_i, err_body, path, method)
        end

        return {} if response.code.to_i == 204 || response.body.nil? || response.body.empty?

        JSON.parse(response.body)
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
      def self.update_method
        @update_method || 'PATCH'
      end

      def self.update_method=(m)
        @update_method = m
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
  end
end
