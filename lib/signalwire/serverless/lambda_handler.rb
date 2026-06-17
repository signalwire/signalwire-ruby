# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'base64'
require 'json'
require 'stringio'
require 'uri'

module SignalWire
  module Serverless
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

      private

      # ------------------------------------------------------------------
      # Request: Lambda event -> Rack env
      # ------------------------------------------------------------------

      def build_env(event)
        version = detect_version(event)
        method  = extract_method(event, version)
        path    = extract_path(event, version)
        query   = extract_query_string(event, version)
        headers = extract_headers(event)
        body_io, content_length = extract_body(event)

        env = {
          'REQUEST_METHOD' => method,
          'SCRIPT_NAME' => '',
          'PATH_INFO' => path,
          'QUERY_STRING' => query,
          'SERVER_NAME' => headers['host'] || 'lambda',
          'SERVER_PORT' => headers['x-forwarded-port'] || '443',
          'SERVER_PROTOCOL' => 'HTTP/1.1',
          'HTTP_VERSION' => 'HTTP/1.1',
          'rack.version' => [1, 6],
          'rack.url_scheme' => headers['x-forwarded-proto'] || 'https',
          'rack.input' => body_io,
          'rack.errors' => $stderr,
          'rack.multithread' => false,
          'rack.multiprocess' => false,
          'rack.run_once' => true,
          'rack.hijack?' => false,
          'signalwire.lambda_event' => event
        }
        env['CONTENT_LENGTH'] = content_length.to_s if content_length
        env['CONTENT_TYPE']   = headers['content-type'] if headers['content-type']

        headers.each do |name, value|
          next if %w[content-type content-length].include?(name)

          env["HTTP_#{name.tr('-', '_').upcase}"] = value
        end

        env
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

        pairs = []
        params.each do |k, v|
          if v.is_a?(Array)
            v.each { |vv| pairs << [k, vv] }
          else
            pairs << [k, v]
          end
        end
        URI.encode_www_form(pairs)
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

      # ------------------------------------------------------------------
      # Response: Rack triple -> Lambda response hash
      # ------------------------------------------------------------------

      def build_response(event, status, headers, body)
        payload = collect_body(body)
        encoded, is_base64 = maybe_base64(payload, headers)

        flat_headers = {}
        multi_headers = {}
        (headers || {}).each do |name, value|
          key = name.to_s
          if value.is_a?(Array)
            flat_headers[key]  = value.join(',')
            multi_headers[key] = value
          else
            flat_headers[key] = value.to_s
          end
        end

        if detect_version(event) == 2
          response = {
            'statusCode' => status.to_i,
            'headers' => flat_headers,
            'body' => encoded,
            'isBase64Encoded' => is_base64
          }
          response['cookies'] = multi_headers['set-cookie'] if multi_headers.key?('set-cookie')
          response
        else
          {
            'statusCode' => status.to_i,
            'headers' => flat_headers,
            'multiValueHeaders' => multi_headers,
            'body' => encoded,
            'isBase64Encoded' => is_base64
          }
        end
      end

      def collect_body(body)
        return ''.b if body.nil?

        parts = []
        body.each { |chunk| parts << chunk.to_s }
        parts.join.b
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
  end
end
