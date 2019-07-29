# frozen_string_literal: true

module Signalwire::Relay
  class Client
    include Signalwire::Logger
    include Signalwire::Common
    include Signalwire::Blade::EventHandler

    attr_accessor :project, :host, :url, :protocol, :connected, :session

    # Creates a Relay client
    #
    # @param project [String] Your SignalWire project identifier
    # @param token [String] Your SignalWire secret token
    # @param SIGNALWIRE_HOST [String] Your SignalWire space URL (not needed for production usage)

    def initialize(project:, token:, host: nil)
      @project = project
      @token = token
      @host = host || ENV.fetch('SIGNALWIRE_HOST', Signalwire::Relay::DEFAULT_URL)
      @url = clean_up_space_url(@host)
      @protocol = nil

      @connected = false

      setup_session
      setup_handlers
      setup_events
    end

    # Starts the client connection
    #
    def connect!
      logger.debug "Connecting to #{@url}"
      session.connect!
    end

    # Terminates the session
    #
    def disconnect!
      session.disconnect!
    end

    def clean_up_space_url(space_url)
      uri = URI.parse(space_url)
      # oddly, URI.parse interprets a simple hostname as a path
      if uri.scheme.nil? && uri.host.nil?
        unless uri.path.nil?
          uri.scheme = 'wss'
          uri.host = uri.path
          uri.path = ''
        end
      end

      uri.to_s
    end

    def execute(command, &block)
      @session.execute(command, &block)
    end

    # TODO: refactor this for style
    def relay_execute(command, timeout = Signalwire::Relay::COMMAND_TIMEOUT, &block)
      promise = Concurrent::Promises.resolvable_future

      execute(command) do |event|
        promise.fulfill event
      end

      promise.wait timeout

      if promise.fulfilled?
        event = promise.value
        code = event.dig(:result, :result, :code)
        message = event.dig(:result, :result, :message)
        success = code == '200' ? :success : :failure

        if code
          block.call(event, success) if block_given?
          logger.error "Relay command failed with code #{code} and message: #{message}" unless success
        else
          logger.error 'Unknown Relay command failure, result code not found'
        end
      else
        logger.error 'Unknown Relay command failure, command timed out'
      end
    end

    def calling
      @calling ||= Signalwire::Relay::Calling::Instance.new(self)
    end

    def messaging
      @messaging ||= Signalwire::Relay::Messaging::Instance.new(self)
    end

    def setup_context(context)
      return if contexts.include?(context)
      receive_command = {
        protocol: @protocol,
        method: 'call.receive',
        params: {
          context: context
        }
      }

      relay_execute receive_command do
        contexts << context
      end
    end

    def contexts
      @contexts ||= Concurrent::Array.new
    end

  private

    def setup_handlers
      @session.on :connected do |event|
        logger.debug 'Relay client connected'
        broadcast :connecting, event
        protocol_setup
      end
    end

    def protocol_setup
      setup = {
        protocol: 'signalwire',
        method: 'setup',
        params: {
        }
      }

      # hijack our protocol
      setup[:params][:protocol] = @protocol if @protocol

      @session.execute(setup) do |event|
        @protocol = event.dig(:result, :result, :protocol)
        logger.debug "Protocol set up as #{protocol}"

        notification_request = {
          "protocol": @protocol,
          "command": 'add',
          "channels": ['notifications']
        }

        @session.subscribe(notification_request) do
          logger.debug "Subscribed to notifications for #{protocol}"
          @connected = true
          broadcast :ready, self
        end
      end
    end

    def setup_session
      auth = {
        project: @project,
        token: @token
      }
      @session = Signalwire::Blade::Connection.new(url: url, authentication: auth)
    end

    def setup_events
      @session.on :message, %i[\[\] method] => 'blade.broadcast' do |event|
        relay = Signalwire::Relay::Event.from_blade(event)
        broadcast :event, relay
        broadcast :task, relay if relay.dig(:params, :event) == "queuing.relay.tasks"
      end
    end
  end
end
