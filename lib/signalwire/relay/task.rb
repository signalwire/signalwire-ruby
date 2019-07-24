require 'uri'
require 'faraday'
require 'json'

module Signalwire::Relay
  class Task
    DEFAULT_HOST = "relay.signalwire.com"
    attr_accessor :host

    def initialize(project:, token:, host: nil )
      @project = project
      @token = token
      @host = host || DEFAULT_HOST
    end

    def deliver(context:, message: )
      message = JSON.generate({
        context: context,
        message: message
      })
      conn = Faraday.new(
        url: normalize_host(@host),
        headers: {'Content-Type' => 'application/json'}
      )
      conn.basic_auth(@project, @token)

      resp = conn.post('/api/relay/rest/tasks') do |req|
        req.body = message
      end
      return resp.status == 204
    end

    def normalize_host(passed_host)
      uri = URI.parse(passed_host)
      if uri.scheme.nil? && uri.host.nil?
        unless uri.path.nil?
          uri.scheme = 'https'
          uri.host = uri.path
          uri.path = ''
        end
      end
      uri.to_s
    end
  end
end
