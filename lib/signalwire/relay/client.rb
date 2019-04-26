require 'uri'
module Signalwire::Relay
  class Client
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Blade::Logging::HasLogger

    attr_accessor :calls, :project, :space_url
    def initialize(project:, token:, signalwire_space_url: nil)
      @project = project
      @token = token
      @space_url = clean_up_space_url(signalwire_space_url)
      @calls = {}

      setup_session
      setup_handlers
    end

    def clean_up_space_url(space_url)
      base_url = space_url || ENV.fetch['SIGNALWIRE_SPACE_URL'] ||
      raise(ArgumentError,
        'SignalWire Space URL is not configured. Enter your SignalWire Space domain via the '\
        'SIGNALWIRE_SPACE_URL environment variables, or the signalwire_space_url parameter')

      uri = URI.parse(space_url)
      # oddly, URI.parse interprets a simple hostname as a path
      if uri.scheme.nil? && uri.host.nil?
        unless uri.path.nil?
          uri.scheme = "wss"
          uri.host = uri.path
          uri.path = '/api/relay/wss'
          uri.port = 443
        end
      end

      uri.to_s
    end

    def connect!
      @session.start!
    end

    private

    def setup_session
      @session = Signalwire::Blade::Session.new(project: @project, token: @token, blade_address: @space_url)

      @session.once :connected do |event|
        trigger_handler :ready, event
      end
    end

    def setup_handlers
      on :ready do |event|
        logger.info "Relay client connected"
      end
    end
  end
end