# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'base64'
require 'json'
require 'stringio'
require 'uri'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Serverless — adapters that run an agent under Lambda / CGI / GCF / Azure.
  module Serverless
    # Private mixin: translates a Rack response triple into the Lambda
    # response-hash shape. Extracted from {LambdaHandler} purely to keep that
    # class within the size budget; every method is private and depends only
    # on +detect_version+ (provided by the host class).
    module ResponseTranslation
      private

      def build_response(event, status, headers, body)
        payload = collect_body(body)
        encoded, is_base64 = maybe_base64(payload, headers)
        flat_headers, multi_headers = split_response_headers(headers)

        if detect_version(event) == 2
          response_v2(status, flat_headers, multi_headers, encoded, is_base64)
        else
          response_v1(status, flat_headers, multi_headers, encoded, is_base64)
        end
      end

      # Split a Rack header hash into flat (comma-joined) and multi-value forms.
      def split_response_headers(headers)
        flat_headers = {}
        multi_headers = {}
        (headers || {}).each do |name, value|
          key = name.to_s
          flat_headers[key] = value.is_a?(Array) ? value.join(',') : value.to_s
          multi_headers[key] = value if value.is_a?(Array)
        end
        [flat_headers, multi_headers]
      end

      def response_v2(status, flat_headers, multi_headers, encoded, is_base64)
        response = {
          'statusCode' => status.to_i,
          'headers' => flat_headers,
          'body' => encoded,
          'isBase64Encoded' => is_base64
        }
        response['cookies'] = multi_headers['set-cookie'] if multi_headers.key?('set-cookie')
        response
      end

      def response_v1(status, flat_headers, multi_headers, encoded, is_base64)
        {
          'statusCode' => status.to_i,
          'headers' => flat_headers,
          'multiValueHeaders' => multi_headers,
          'body' => encoded,
          'isBase64Encoded' => is_base64
        }
      end

      def collect_body(body)
        return ''.b if body.nil?

        body.join.b
      end

      # Lambda requires the 'body' field to be a UTF-8 string; binary
      # responses have to be base64 encoded and flagged as such. Any byte
      # that isn't valid UTF-8 forces base64 encoding.
      def maybe_base64(payload, _headers)
        if payload.force_encoding(Encoding::UTF_8).valid_encoding?
          [payload.to_s, false]
        else
          [Base64.strict_encode64(payload), true]
        end
      end
    end

    # Private mixin: translates a Lambda invocation event into a Rack env.
    # Extracted from {LambdaHandler} purely to keep that class within the size
    # budget; every method is private.
    module RequestTranslation
      # Header names handled as CONTENT_* (not HTTP_*) in the Rack env.
      SKIPPED_HTTP_HEADERS = %w[content-type content-length].freeze

      # Rack env keys that never depend on the incoming Lambda event.
      STATIC_RACK_ENV = {
        'SCRIPT_NAME' => '',
        'SERVER_PROTOCOL' => 'HTTP/1.1',
        'HTTP_VERSION' => 'HTTP/1.1',
        'rack.version' => [1, 6],
        'rack.multithread' => false,
        'rack.multiprocess' => false,
        'rack.run_once' => true,
        'rack.hijack?' => false
      }.freeze

      private

      def build_env(event)
        version = detect_version(event)
        headers = extract_headers(event)
        body_io, content_length = extract_body(event)
        env = base_rack_env(event, version, headers, body_io)
        env['CONTENT_LENGTH'] = content_length.to_s if content_length
        env['CONTENT_TYPE']   = headers['content-type'] if headers['content-type']
        add_http_headers(env, headers)
        env
      end

      def base_rack_env(event, version, headers, body_io)
        STATIC_RACK_ENV.merge(
          'REQUEST_METHOD' => extract_method(event, version),
          'PATH_INFO' => extract_path(event, version),
          'QUERY_STRING' => extract_query_string(event, version),
          'SERVER_NAME' => headers['host'] || 'lambda',
          'SERVER_PORT' => headers['x-forwarded-port'] || '443',
          'rack.url_scheme' => headers['x-forwarded-proto'] || 'https',
          'rack.input' => body_io, 'rack.errors' => $stderr,
          'signalwire.lambda_event' => event
        )
      end

      def add_http_headers(env, headers)
        headers.each do |name, value|
          next if SKIPPED_HTTP_HEADERS.include?(name)

          env["HTTP_#{name.tr('-', '_').upcase}"] = value
        end
      end

      def detect_version(event)
        # API Gateway HTTP API / Function URLs use payload v2 and include
        # a 'version' key of "2.0". Everything else (REST API, ALB, direct
        # invoke) is treated as v1.
        event['version'].to_s.start_with?('2') ? 2 : 1
      end

      def extract_method(event, version)
        if version == 2
          event.dig('requestContext', 'http', 'method') || event['httpMethod'] || 'GET'
        else
          event['httpMethod'] || 'GET'
        end
      end

      def extract_path(event, _version)
        raw =
          event['rawPath'] ||
          event['path'] ||
          event.dig('requestContext', 'http', 'path') ||
          '/'
        raw = "/#{raw}" unless raw.start_with?('/')
        raw
      end

      def extract_query_string(event, _version)
        return event['rawQueryString'] if event['rawQueryString'] && !event['rawQueryString'].empty?

        params = event['multiValueQueryStringParameters'] || event['queryStringParameters']
        return '' if params.nil? || params.empty?

        URI.encode_www_form(query_param_pairs(params))
      end

      def query_param_pairs(params)
        params.flat_map do |k, v|
          v.is_a?(Array) ? v.map { |vv| [k, vv] } : [[k, v]]
        end
      end

      def extract_headers(event)
        raw = event['headers'] || {}
        multi = event['multiValueHeaders'] || {}

        merged = {}
        raw.each { |k, v| merged[k.downcase] = v }
        multi.each do |k, values|
          key = k.downcase
          merged[key] = Array(values).join(',') unless merged.key?(key)
        end
        merged
      end

      def extract_body(event)
        body = event['body']
        return [StringIO.new(''.b), nil] if body.nil? || body.empty?

        decoded = event['isBase64Encoded'] ? Base64.decode64(body) : body.dup
        decoded = decoded.b
        [StringIO.new(decoded), decoded.bytesize]
      end
    end

    # Adapter that lets an AWS Lambda function invoke a Rack application.
    #
    # Typical usage from a Lambda entrypoint file:
    #
    #   require 'signalwire'
    #
    #   AGENT = SignalWire::AgentBase.new(name: 'my-agent', route: '/')
    #   # ...configure AGENT...
    #
    #   HANDLER = SignalWire::Serverless::LambdaHandler.new(AGENT.rack_app)
    #
    #   def handler(event:, context:)
    #     HANDLER.call(event, context)
    #   end
    #
    # The adapter accepts events from either Lambda Function URLs / API
    # Gateway HTTP API (payload format v2) or the classic API Gateway REST
    # API (payload format v1) and returns a response in the matching
    # shape. Any triple returned by the Rack app (status, headers, body)
    # is translated into the +{statusCode:, headers:, body:}+ shape
    # expected by Lambda.
    #
    # The adapter never reaches out to the network and has no gem
    # dependencies beyond what the SignalWire SDK already requires, so it
    # can be bundled directly into a Lambda zip.
    class LambdaHandler
      include RequestTranslation
      include ResponseTranslation

      # @param app [#call] a Rack-compatible application
      def initialize(app)
        raise ArgumentError, 'app must respond to #call' unless app.respond_to?(:call)

        @app = app
      end

      # Invoke the wrapped Rack application with a Lambda event.
      #
      # @param event   [Hash]   the Lambda invocation event
      # @param _context [Object] the Lambda context (ignored)
      # @return [Hash] a Lambda-shaped response hash
      def call(event, _context = nil)
        event ||= {}
        env = build_env(event)

        status, headers, body = @app.call(env)

        build_response(event, status, headers, body)
      ensure
        body.close if body.respond_to?(:close)
      end

      # Class-level convenience so consumers can use
      # +SignalWire::Serverless::LambdaHandler.for(agent)+ without
      # duplicating +.rack_app+ at the call site.
      #
      # @param agent_or_app [Object] either an AgentBase (responds to
      #   +rack_app+) or any Rack-compatible application
      # @return [LambdaHandler]
      def self.for(agent_or_app)
        app = if agent_or_app.respond_to?(:rack_app)
                agent_or_app.rack_app
              else
                agent_or_app
              end
        new(app)
      end
    end
  end
end
