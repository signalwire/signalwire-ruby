module Signalwire::Blade
  class Session
    include Logging::HasLogger
    include HasGuardedHandlers
    attr_reader :session_id, :connected, :node_id, :connection

    def initialize(options = {})
      @options = options
      @session_id = nil
      @node_id = nil
      @connected = false
      
      blade_address = @options.delete(:blade_address)
      @connection = Connection.new(self, blade_address)
      @node_store = NodeStore.new(self)
    end

    def start!
      on :started do |event|
        execute(connect_request) do |event|
          @session_id = event[:sessionid]
          @node_id = event[:nodeid]
          @node_store.populate_from_connect(event)
          @connected = true
          logger.info "Session connected with id: #{@session_id}"

          trigger_handler :connected, Event.new(:connected, { session_id: session_id, node_id: node_id })
        end
      end

      on :incomingcommand, method: 'blade.netcast' do |event|
        @node_store.netcast_update(event.params)
      end

      # if @options[:async]
      #   @connection.async.start
      # else
      @connection.start
      # end
    rescue SignalException => e
      stop!
    rescue => e
      logger.error e.inspect
    end

    def stop!
      @connection.shutdown
    end

    def execute(command, &block)
      once(:result, id: command.id, &block) if block_given?
      @connection.transmit(command.to_json)
    end

    alias_method :on, :register_handler
    alias_method :once, :register_tmp_handler

    private

    def connect_request
      command = ConnectRequest.new(@session_id)
      command.project = @options[:project] unless @options[:project].nil?
      command.token = @options[:token] unless @options[:token].nil?

      command
    end
  end
end
