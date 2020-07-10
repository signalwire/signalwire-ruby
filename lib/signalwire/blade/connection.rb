# frozen_string_literal: true

require 'has_guarded_handlers'
require 'eventmachine'
require 'faye/websocket'
require 'json'
require 'concurrent-ruby'

module Signalwire::Blade
  class Connection
    include Signalwire::Logger
    include Signalwire::Blade::EventHandler
    include Signalwire::Common

    attr_reader :session_id, :connected, :node_id, :connection

    def initialize(**options)
      @options = options
      @session_id = nil
      @node_id = nil
      @connected = false
      @url = @options.fetch(:url, 'wss://relay.signalwire.com')
      @log_traffic = options.fetch(:log_traffic, true)
      @authentication = options.fetch(:authentication, nil)

      @pong = Concurrent::AtomicBoolean.new

      @inbound_queue = EM::Queue.new
      @outbound_queue = EM::Queue.new

      @keep_alive_timer = nil

      @shutdown_list = []
    end

    def connect!
      setup_started_event
      enable_epoll
      handle_signals

      main_loop!
    end

    def reconnect!
      clear_connections
      return if @shutdown
      sleep Signalwire::Blade::RECONNECT_PERIOD
      logger.info "Attempting reconnection"
      main_loop!
    end

    def main_loop!
      EM.run do
        logger.info "CREATING SOCKET"
        @ws = Faye::WebSocket::Client.new(@url)

        @ws.on(:open) { |event| broadcast :started, event }
        @ws.on(:message) { |event| enqueue_inbound event }
        @ws.on(:close) { logger.error "CLOSE TRIGGERED"; handle_close }

        @ws.on :error do |error|
          logger.error "Error occurred: #{error.message}"
        end

        schedule_flush_queues
      end
    end

    def schedule_flush_queues
      EM.add_timer(0.005) { flush_queues }
    end

    def setup_started_event
      on :started do |_event|
        begin
          @connected = true
          myreq = connect_request
          @pong.make_false

          write_command(myreq) do |event|
            @session_id = event.dig(:result, :sessionid) unless @session_id
            @node_id = event.dig(:result, :nodeid) unless @node_d
            logger.info "Blade Session connected with id: #{@session_id}"
            broadcast :connected, event
            keep_alive
          end

        rescue StandardError => e
          logger.error e.inspect
          logger.error e.backtrace
        end
      end
    end

    def enable_epoll
      # This is only enabled on Linux
      EM.epoll
      logger.debug "Running with epoll #{EM.epoll?}"
    end

    def transmit(message)
      enqueue_outbound message
    end

    def write(message)
      log_traffic :send, message
      @ws.send(message)
    end

    def receive(message)
      event = Message.from_json(message.data)
      log_traffic :recv, event.payload
      EM.defer do
        broadcast :message, event
      end
    end

    def write_command(command, &block)
      if block_given?
        once :message, id: command.id do |event|
          handle_execute_response(event, &block)
        end
      end

      transmit(command.build_request.to_json)
    end

    def handle_execute_response(event, &block)
      logger.error("Blade error occurred, code #{event.error_code}: #{event.error_message}") if event.error?
      block.call(event)
    end

    def execute(params, &block)
      block_given? ? write_command(Execute.new(params), &block) : write_command(Execute.new(params))
    end

    def ping(&block)
      ping_cmd = Ping.new
      block_given? ? write_command(ping_cmd, &block) : write_command(ping_cmd)
      ping_cmd
    end

    def subscribe(params, &block)
      block_given? ? write_command(Subscribe.new(params), &block) : write_command(Subscribe.new(params))
    end

    def handle_close
      logger.warn "WS Socket closed!"
      reconnect!
    end

    def clear_connections
      @ws = nil
      @connected = false
      @keep_alive_timer.cancel if @keep_alive_timer
    end

    def disconnect!
      # logger.info 'Stopping Blade event loop'
      clear_connections
      EM.stop
    end

    def flush_queues
      @inbound_queue.pop { |inbound| receive(inbound) } until @inbound_queue.empty?
      if connected?
        @outbound_queue.pop { |outbound| write(outbound) } until @outbound_queue.empty?
      end

      schedule_flush_queues
    end

    def enqueue_inbound(message)
      @inbound_queue.push message
    end

    def enqueue_outbound(message)
      @outbound_queue.push message
    end

    def connect_request
      req = Connect.new
      req[:params][:authentication] = @authentication if @authentication
      req
    end

    def connected?
      @connected == true
    end

    def keep_alive
      @pong.make_false

      @ping = ping do
        logger.info "Pong received"
        @pong.make_true
      end

      @keep_alive_timer = EventMachine::Timer.new(Signalwire::Relay::PING_TIMEOUT) do
        if @pong.false?
          logger.error "Ping failed, pong is #{@pong.value}, ping is #{ping.id}"  
          #reconnect! if connected? && @pong.false?
        else
          sleep 0.5
          keep_alive
        end
      end
    end

    def log_traffic(direction, message)
      if @log_traffic
        pretty = case direction
                 when :send
                   JSON.pretty_generate(JSON.parse(message))
                 when :recv
                   JSON.pretty_generate(message)
                 end
      end
      logger.debug "#{direction.to_s.upcase}: #{pretty}"
    end

    def handle_signals
      Signal.trap('INT') do
        shutdown_from_signal
      end
      
      Signal.trap('TERM') do
        shutdown_from_signal
      end
    end


    def shutdown_from_signal
      @shutdown = true
      shutdown_registered
      disconnect!
      exit
    end

    def register_for_shutdown(obj)
      @shutdown_list << obj
    end

    def shutdown_registered
      @shutdown_list.each do |obj|
        obj.stop
      end
    end
  end
end
