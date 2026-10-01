# frozen_string_literal: true

# Copyright (c) 2026 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Namespace holding the AI Chat client's error family, response models and
  # the browser-facing gateway.
  module AIChat
    # @api private
    #
    # The Rack plumbing {ChatGateway} and {HandoffRouter} share: the bounded JSON
    # body read, JSON answers, and the UTF-8 size measure. Mixed in as PRIVATE
    # instance methods, so it adds nothing to either class's public surface.
    module RackSupport
      private

      # Parse a request's JSON body, refusing one over +limit+ bytes.
      #
      # A declared +Content-Length+ over the limit is refused before anything is
      # read. The body is then read in chunks and abandoned as soon as it passes
      # the limit, so a chunked or understated upload can't make the process hold
      # more than +limit+ bytes of it.
      #
      # @raise [GatewayRejection] 413 when the body is over +limit+
      # @raise [JSON::ParserError] when the body isn't valid JSON
      def read_json_body(env, limit = ChatGateway::MAX_REQUEST_BODY_BYTES)
        declared = env['CONTENT_LENGTH'].to_s
        raise GatewayRejection.new(413, 'request too large') if declared.match?(/\A\d+\z/) && declared.to_i > limit

        JSON.parse(read_bounded(env['rack.input'], limit))
      end

      # Read at most +limit+ bytes of +input+, raising 413 the moment it passes.
      def read_bounded(input, limit)
        received = +''
        return received if input.nil?

        while (chunk = input.read(16_384))
          received << chunk
          raise GatewayRejection.new(413, 'request too large') if received.bytesize > limit
        end
        received
      end

      # A JSON answer: +[status, headers, [body]]+ with lowercase header names.
      def json_response(status, payload, headers = {})
        [status, { 'content-type' => 'application/json' }.merge(headers), [JSON.generate(payload)]]
      end

      # A refusal that lets Rack::Cascade try the next app sharing the prefix.
      def cascade_response
        [404, { 'content-type' => 'application/json', 'x-cascade' => 'pass' },
         [JSON.generate('error' => 'not found')]]
      end

      # The request path relative to the mount point, without a trailing slash.
      def route_path(env)
        path = env['PATH_INFO'].to_s
        path.end_with?('/') ? path.chomp('/') : path
      end

      # Length of +text+ in UTF-8 bytes — what the service is actually sent.
      def utf8_len(text)
        text.to_s.bytesize
      end
    end
  end
end
