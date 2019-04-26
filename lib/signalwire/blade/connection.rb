require "nio"
require "openssl"
require "websocket/driver"
require "uri"
require "concurrent"

module Signalwire::Blade
  class Connection
    include Logging::HasLogger
    attr_reader :url
    attr_reader :send_rate
    attr_reader :recv_rate

    DEFAULT_PORTS = {'ws' => 80, 'wss' => 443}

    def initialize(session, address = nil)

      @session = session
      @teardown = false
      @executor = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 10, max_queue: 10, fallback_policy: :caller_runs)
      @url = address || EnvVars::BLADE_ADDRESS

      # Instantiate our calculators
      @send_rate = Util::Throughput.new
      @recv_rate = Util::Throughput.new
    end

    def start
      connect
      @thread = Thread.new { event_loop }
      @thread.join
    end

    def event_loop
      loop do
        break if @teardown
        next if @nio.empty?
        @nio.select do |monitor|
          incoming = monitor.io.read_nonblock(4096, exception: false)
          @executor << -> { @driver.parse(incoming) }
        end
      end
      logger.info "Closing event loop"
    end

    def transmit(message)
      @executor << -> {
        logger.debug "SEND: #{message}"
        report_rate(message, @send_rate)
        case message
        when Numeric then @driver.text(message.to_s)
        when String then @driver.text(message)
        when Array then @driver.binary(message)
        else false
        end
      }
    end

    def write(data)
      @ssl_socket.write_nonblock(data)
    end

    def close
      return if @teardown
      sleep 1
      connect
    end

    def shutdown
      @teardown = true
      @driver.close
      @nio.close
      @executor.shutdown
      success = @executor.wait_for_termination 2
      @executor.kill unless success

      @send_rate.stop
      @recv_rate.stop
    end

    def handle_incoming(event)
      logger.debug "RECV: #{event.data}"
      report_rate(event.data, @recv_rate)
      json = JSON.parse(event.data, symbolize_names: true)
      
      if json.has_key? :method
        @session.trigger_handler( :incomingcommand, IncomingCommand.new(json[:id], json[:method], json[:params]) )
      elsif json.has_key? :result
        @session.trigger_handler( :result, Result.new(json[:id], json[:result]) )

      elsif json.has_key? :error
        @session.trigger_handler( :error, Error.new(json[:id], json[:error]) )
      else
        logger.error "Unknown message: #{event.data}"
      end
    rescue => e
      logger.error e.inspect
      logger.error e.backtrace
    end

    private

    def connect
      setup_socket
      setup_nio
      setup_driver

      @ssl_socket.connect
      @driver.start
    end

    def ssl_context
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.cert_store = OpenSSL::X509::Store.new
      ctx.cert_store.set_default_paths
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
      if EnvVars::CERTIFIED
        if !File.file?(EnvVars::BLADE_SSL_CHAIN) || !File.file?(EnvVars::BLADE_SSL_KEY)
          raise "Files for 'BLADE_SSL_KEY' or 'BLADE_SSL_CHAIN' could not found."
        end
        ctx.cert = OpenSSL::X509::Certificate.new(File.read(EnvVars::BLADE_SSL_CHAIN))
        ctx.key = OpenSSL::PKey::RSA.new(File.read(EnvVars::BLADE_SSL_KEY))
      end

      ctx
    end

    def setup_socket
      @uri = URI.parse(@url)
      @port = @uri.port || DEFAULT_PORTS[@uri.scheme]
      @tcp_socket = TCPSocket.new(@uri.host, @port)
      @ssl_socket = OpenSSL::SSL::SSLSocket.new(@tcp_socket, ssl_context)
      @ssl_socket.sync_close = true
    end

    def setup_nio
      @nio = NIO::Selector.new
      @nio.register(@ssl_socket, :r)
    end

    def setup_driver
      @driver = WebSocket::Driver.client(self)
      @driver.on(:open) { |event| @session.trigger_handler(:started, event) }
      @driver.on(:message) { |event| handle_incoming(event) }
      @driver.on(:close) { |event| close }
    end

    def report_rate(message, direction)
      size = message.size rescue 0
      direction.report(size) if size > 0
    end
  end
end
