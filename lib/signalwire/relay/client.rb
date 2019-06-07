require 'uri'
module Signalwire::Relay
  class Client
    include ::Signalwire::Relay::EventHandler
    include ::Signalwire::Relay::Calling
    include ::Signalwire::Blade::Logging::HasLogger

    attr_accessor :project, :space_url, :protocol, :connected, :session
    def initialize(project:, token:, signalwire_space_url: nil)
      @project = project
      @token = token
      @space_url = clean_up_space_url(signalwire_space_url)

      @connected = false

      setup_session
      setup_call_event_handlers
      setup_handlers
      setup_events
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
      logger.debug "Starting up Relay session"
      @session.start!
    end

    def disconnect!
      @session.stop!
    end

    def execute(command, &block)
      @session.execute(command, &block)
    end

    def relay_execute(command, &block)
      execute(command) do |event|
        if event.result[:result] && event.result[:result][:code]
          if event.result[:result][:code] == '200'
            block.call(event) if block_given?
          else
            logger.error "Relay command failed with code #{event.result[:result][:code]} and message: #{event.result[:result][:code]}"
          end
        else
          logger.error "Unknown Relay command failure, result code not found"
        end
      end
    end

    private

    def setup_session
      @session = Signalwire::Blade::Session.new(project: @project, token: @token, blade_address: @space_url)

      @session.once :connected do |event|
        broadcast :connecting, event
      end
    end

    def setup_handlers
      on :connecting do |event|
        logger.debug "Relay client connected"
        @session.execute(ProtocolSetupRequest.new) do |event|
          @protocol = event.result[:result][:protocol]
          logger.debug "Protocol set up as #{protocol}"
          @session.execute(SubscribeNotificationsRequest.new(protocol)) do |event|
            logger.debug "Subscribed to notifications for #{protocol}"
            @connected = true
            broadcast :ready, self
          end
        end
      end
    end

    def setup_events
      @session.on :incomingcommand do |event|
        logger.debug event.inspect
        if event.method == "blade.broadcast" && event.params[:event] == 'relay'
          relay = Signalwire::Relay::Event.from_blade(event)
          broadcast :event, relay
        end
      end
    end

    def setup_call_event_handlers
      on :event, proc {|evt| evt.event_type.match(/calling\.call/) && !evt.event_type.match(/receive/) } do |event|
        found_call = find_call_by_id(event.call_id) || find_call_by_tag(event.call_params[:tag])
        if found_call
          found_call.broadcast :event, event 
        else
          logger.warn "RECEIVED EVENT FOR UNKNOWN CALL #{event.inspect}"
        end
      end
    end
  end
end