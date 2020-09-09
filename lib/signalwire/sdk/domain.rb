# frozen_string_literal: true

module Twilio
  module REST
    class Domain
      attr_reader :client

      def initialize(client)
        @client = client
        @host = nil
        @base_url = nil
        @port = nil
      end

      def absolute_url(uri)
        if Signalwire::Sdk.configuration.service_provider == 'twilio'
          "#{@base_url.chomp('/')}/#{uri.chomp('/').gsub(/^\//, '')}"
        else
          "#{@base_url.chomp('/')}/#{uri.chomp('/').gsub(%r{^/(api/)/}, '')}"
        end
      end

      def request(method, uri, params = {}, data = {}, headers = {}, auth = nil, timeout = nil)
        url = uri.match(/^http/) ? uri : absolute_url(uri)

        @client.request(
            @base_url,
            @port,
            method,
            url,
            params,
            data,
            headers,
            auth,
            timeout
        )
      end
    end
  end
end
