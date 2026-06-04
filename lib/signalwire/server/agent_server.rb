# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'
require 'thread'
require_relative '../logging'

module SignalWire
  # Multi-agent hosting on a single Rack application.
  #
  #   server = AgentServer.new(host: '0.0.0.0', port: 3000)
  #   server.register(my_agent, route: '/agent1')
  #   server.register(my_agent2, route: '/agent2')
  #   server.run
  #
  class AgentServer
    attr_reader :host, :port, :log_level, :logger

    # Public Rack application — Python parity: ``server.app`` exposes
    # the underlying FastAPI instance. Ruby exposes the cached Rack
    # app (a Proc) so callers can mount it on their own server or
    # pass it to Rack-compatible test harnesses.
    def app
      @rack_app ||= rack_app
    end

    # MIME types for static file serving.
    MIME_TYPES = {
      '.html' => 'text/html',
      '.htm'  => 'text/html',
      '.css'  => 'text/css',
      '.js'   => 'application/javascript',
      '.json' => 'application/json',
      '.png'  => 'image/png',
      '.jpg'  => 'image/jpeg',
      '.jpeg' => 'image/jpeg',
      '.gif'  => 'image/gif',
      '.svg'  => 'image/svg+xml',
      '.ico'  => 'image/x-icon',
      '.txt'  => 'text/plain',
      '.xml'  => 'application/xml',
      '.woff' => 'font/woff',
      '.woff2' => 'font/woff2',
      '.ttf'  => 'font/ttf',
      '.eot'  => 'application/vnd.ms-fontobject',
      '.map'  => 'application/json',
      '.webp' => 'image/webp',
      '.pdf'  => 'application/pdf'
    }.freeze

    # Security headers applied to static file responses.
    STATIC_SECURITY_HEADERS = {
      'x-content-type-options' => 'nosniff',
      'x-frame-options'        => 'DENY',
      'cache-control'          => 'no-store, no-cache, must-revalidate'
    }.freeze

    # Construct an AgentServer.
    #
    # Python parity: ``AgentServer(host, port, log_level)`` —
    # ``log_level`` controls the AgentServer's logger verbosity. The
    # Ruby port maps it through ``SignalWire::Logging.logger`` so the
    # WARN/INFO/DEBUG semantics match Python's ``logging`` levels.
    #
    # @param host [String] bind address (default ``"0.0.0.0"``)
    # @param port [Integer] bind port (default ``3000``)
    # @param log_level [String] log level — one of ``"debug"``,
    #   ``"info"``, ``"warning"``/``"warn"``, ``"error"``,
    #   ``"critical"``/``"fatal"``. Default ``"info"``.
    def initialize(host: '0.0.0.0', port: 3000, log_level: 'info')
      @host      = host
      @port      = port
      @log_level = log_level.to_s.downcase
      @agents = {}   # route => agent object
      @sip_routes = {}  # username => route
      @static_routes = {} # route => directory
      @mutex  = Mutex.new

      @logger = Logging.logger("AgentServer")
      _apply_log_level(@logger, @log_level)
    end

    # Map a Python-style log level string to the underlying logger's
    # threshold. Mirrors Python's ``log_level`` mapping in AgentServer
    # so callers get equivalent verbosity controls.
    #
    # The SignalWire stdlib logger doesn't expose a per-instance
    # ``level=``; we attach a ``@level`` ivar to the underlying
    # ``Logger`` so introspection-style tests can check it. The
    # ``::Logger`` constant from Ruby's stdlib (``require 'logger'``)
    # exposes DEBUG/INFO/WARN/ERROR/FATAL constants we mirror.
    # @api private
    def _apply_log_level(logger, level)
      require 'logger'
      mapped = case level
               when 'debug'                then ::Logger::DEBUG
               when 'info'                 then ::Logger::INFO
               when 'warning', 'warn'      then ::Logger::WARN
               when 'error'                then ::Logger::ERROR
               when 'critical', 'fatal'    then ::Logger::FATAL
               else                              ::Logger::INFO
               end
      if logger.respond_to?(:level=)
        logger.level = mapped
      else
        # SignalWire::Logging::Logger doesn't expose level=; attach
        # via instance_variable so .level reads return the mapped
        # value. We add a singleton accessor.
        logger.instance_variable_set(:@level, mapped)
        unless logger.respond_to?(:level)
          logger.define_singleton_method(:level) { @level }
        end
      end
      mapped
    rescue StandardError
      ::Logger::INFO rescue nil
    end

    # Register an agent at a given route.
    # @param agent [Object] an agent object (e.g. AgentBase or prefab)
    # @param route [String, nil] HTTP route; defaults to agent.route if available
    def register(agent, route: nil)
      route ||= agent.respond_to?(:route) ? agent.route : "/#{agent.object_id}"
      route = "/#{route}" unless route.start_with?('/')

      @mutex.synchronize do
        raise ArgumentError, "Route already registered: #{route}" if @agents.key?(route)
        @agents[route] = agent
      end
      self
    end

    # Unregister an agent by route.
    # @param route [String]
    # @return [Object, nil] the removed agent
    def unregister(route)
      route = "/#{route}" unless route.start_with?('/')
      @mutex.synchronize { @agents.delete(route) }
    end

    # Get all registered agents.
    # @return [Hash] route => agent
    def get_agents
      @mutex.synchronize { @agents.dup }
    end

    # Get a specific agent by route.
    # @param route [String]
    # @return [Object, nil]
    def get_agent(route)
      route = "/#{route}" unless route.start_with?('/')
      @mutex.synchronize { @agents[route] }
    end

    # Set up SIP-based routing.
    # @param route [String] the route to handle SIP requests
    # @param auto_map [Boolean] automatically map agent names as SIP usernames
    def setup_sip_routing(route: '/sip', auto_map: true)
      @sip_route = route
      if auto_map
        @mutex.synchronize do
          @agents.each do |r, agent|
            username = r.sub(%r{^/}, '').tr('/', '_')
            @sip_routes[username] = r
          end
        end
      end
      self
    end

    # Register a routing callback across all agents.
    #
    # Python parity:
    # ``AgentServer.register_global_routing_callback(callback_fn, path)``.
    # Adds unified routing logic to every registered agent at the same
    # path. The +path+ is normalized (leading slash ensured, trailing
    # slash stripped) and the callback is registered on each agent that
    # exposes +register_routing_callback+.
    #
    # The callback may be supplied either as a Ruby block or as a
    # callable (Proc/lambda) +callback_fn+ positional argument, matching
    # Python's function-valued first parameter.
    #
    # @param callback_fn [#call, nil] the routing callback (Proc/lambda)
    # @param path [String] the path to register the callback at
    # @return [self]
    def register_global_routing_callback(callback_fn = nil, path:, &block)
      callback = block || callback_fn
      raise ArgumentError, 'a callback (block or callable) is required' if callback.nil?

      # Normalize the path: ensure a leading slash, strip trailing slash.
      path = "/#{path}" unless path.start_with?('/')
      path = path.chomp('/')

      agents = @mutex.synchronize { @agents.values }
      agents.each do |agent|
        agent.register_routing_callback(path, &callback) if agent.respond_to?(:register_routing_callback)
      end

      @logger&.info("Registered global routing callback at #{path} on all agents")
      self
    end

    # Register a SIP username mapping to a route.
    def register_sip_username(username, route)
      route = "/#{route}" unless route.start_with?('/')
      @mutex.synchronize { @sip_routes[username] = route }
      self
    end

    # Serve static files from a directory at a given route.
    #
    # @param directory [String] absolute or relative path to the directory
    # @param route [String] the URL prefix to serve files at
    # @return [self]
    def serve_static_files(directory, route)
      route = "/#{route}" unless route.start_with?('/')
      route = route.chomp('/')
      resolved = File.expand_path(directory)
      raise ArgumentError, "Directory does not exist: #{resolved}" unless File.directory?(resolved)

      @mutex.synchronize { @static_routes[route] = resolved }
      self
    end

    # Universal run method — mirrors Python's
    # ``AgentServer.run(event=None, context=None, host=None, port=None)``.
    #
    # Detects execution mode and routes appropriately:
    #
    # - **Server mode** — starts WEBrick (Ruby's stdlib HTTP server)
    #   bound to ``host``/``port`` (overrides honoured if supplied).
    # - **Lambda mode** (``AWS_LAMBDA_FUNCTION_NAME`` env var present)
    #   — invokes ``_handle_lambda_request(event, context)`` and
    #   returns the Lambda response Hash.
    # - **CGI mode** (``GATEWAY_INTERFACE`` env var present) — invokes
    #   ``_handle_cgi_request`` and returns the CGI response String.
    #
    # @param event [Object, nil] serverless event (Lambda)
    # @param context [Object, nil] serverless context (Lambda)
    # @param host [String, nil] override bind host (server mode)
    # @param port [Integer, nil] override bind port (server mode)
    # @return [Object, nil] response for serverless modes, nil for
    #   server mode (blocking until shutdown).
    def run(event: nil, context: nil, host: nil, port: nil)
      mode = _detect_execution_mode

      case mode
      when 'lambda'
        _handle_lambda_request(event, context)
      when 'cgi'
        _handle_cgi_request
      else
        _run_server(host, port)
      end
    end

    # @api private
    def _detect_execution_mode
      return 'lambda' if ENV['AWS_LAMBDA_FUNCTION_NAME'] && !ENV['AWS_LAMBDA_FUNCTION_NAME'].empty?
      return 'cgi'    if ENV['GATEWAY_INTERFACE']
      'server'
    end

    # @api private
    def _run_server(host = nil, port = nil)
      bind_host = host || @host
      bind_port = port || @port
      app = rack_app
      require 'webrick'
      server = WEBrick::HTTPServer.new(
        Host: bind_host,
        Port: bind_port,
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
        AccessLog: []
      )
      server.mount('/', Rack::Handler::WEBrick, app) if defined?(Rack::Handler::WEBrick)
      trap('INT') { server.shutdown }
      trap('TERM') { server.shutdown }
      @logger&.info("AgentServer starting on #{bind_host}:#{bind_port}")
      server.start
    end

    # @api private
    # Handle a CGI request — minimal Ruby parity for Python's
    # ``_handle_cgi_request``. Reads ``PATH_INFO``, dispatches to the
    # matching agent, and returns a CGI-formatted response string.
    def _handle_cgi_request
      require 'stringio'
      path_info = (ENV['PATH_INFO'] || '').strip
      env = {
        'PATH_INFO'      => path_info,
        'REQUEST_METHOD' => ENV['REQUEST_METHOD'] || 'GET',
        'QUERY_STRING'   => ENV['QUERY_STRING']   || '',
        'rack.input'     => StringIO.new(''),
        'rack.errors'    => $stderr
      }
      status, headers, body = rack_app.call(env)
      body_str = body.respond_to?(:join) ? body.join : body.to_s

      out = +"Status: #{status}\r\n"
      headers.each { |k, v| out << "#{k}: #{v}\r\n" }
      out << "\r\n"
      out << body_str
      out
    end

    # @api private
    # Handle a Lambda invocation event. Translates the Lambda event
    # shape into a Rack env, dispatches, and returns a Lambda
    # response Hash (statusCode/headers/body).
    def _handle_lambda_request(event, _context)
      require 'stringio'
      event ||= {}
      path = event['path'] || event['rawPath'] || event['pathParameters']&.dig('proxy') || '/'
      method = event['httpMethod'] || event.dig('requestContext', 'http', 'method') || 'GET'
      body = event['body'] || ''
      env = {
        'PATH_INFO'      => path,
        'REQUEST_METHOD' => method,
        'QUERY_STRING'   => '',
        'rack.input'     => StringIO.new(body),
        'rack.errors'    => $stderr
      }
      status, headers, response_body = rack_app.call(env)
      body_str = response_body.respond_to?(:join) ? response_body.join : response_body.to_s
      {
        'statusCode' => Integer(status),
        'headers'    => headers,
        'body'       => body_str
      }
    end

    # Build a Rack application that routes requests to the appropriate agent.
    # @return [Proc] a Rack-compatible app
    def rack_app
      agents        = @agents
      sip_routes    = @sip_routes
      static_routes = @static_routes
      server        = self

      Proc.new do |env|
        path = env['PATH_INFO'] || '/'

        case path
        when '/health', '/healthz'
          body = { status: 'ok', agents: agents.keys }.to_json
          ['200', { 'Content-Type' => 'application/json' }, [body]]

        when '/'
          body = {
            service: 'SignalWire Agent Server',
            agents: agents.keys,
            version: defined?(SignalWire::VERSION) ? SignalWire::VERSION : '1.0.0'
          }.to_json
          ['200', { 'Content-Type' => 'application/json' }, [body]]

        else
          # Check static routes first (longest prefix match)
          static_result = server._try_serve_static(path, static_routes)
          if static_result
            static_result
          else
            # Find the matching agent by longest prefix match
            agent = nil
            matched_route = nil

            agents.each do |route, a|
              if path == route || path.start_with?("#{route}/")
                if matched_route.nil? || route.length > matched_route.length
                  matched_route = route
                  agent = a
                end
              end
            end

            if agent
              if agent.respond_to?(:call)
                agent.call(env)
              elsif agent.respond_to?(:rack_app)
                agent.rack_app.call(env)
              else
                body = { agent: matched_route, status: 'registered' }.to_json
                ['200', { 'Content-Type' => 'application/json' }, [body]]
              end
            else
              body = { error: 'Not found', path: path }.to_json
              ['404', { 'Content-Type' => 'application/json' }, [body]]
            end
          end
        end
      end
    end

    # @api private
    # Attempt to serve a static file. Returns a Rack response or nil.
    def _try_serve_static(path, static_routes)
      matched_route = nil
      matched_dir   = nil

      static_routes.each do |route, directory|
        if path == route || path.start_with?("#{route}/")
          if matched_route.nil? || route.length > matched_route.length
            matched_route = route
            matched_dir   = directory
          end
        end
      end

      return nil unless matched_dir

      # Extract the relative path after the route prefix
      relative = path.sub(matched_route, '')
      relative = '/index.html' if relative.empty? || relative == '/'

      # Path traversal protection: reject any path containing ".."
      if relative.include?('..')
        body = JSON.generate({ error: 'Forbidden' })
        return ['403', STATIC_SECURITY_HEADERS.merge('Content-Type' => 'application/json'), [body]]
      end

      file_path = File.join(matched_dir, relative)
      resolved  = File.expand_path(file_path)

      # Ensure resolved path is still under the served directory
      unless resolved.start_with?(matched_dir + '/')  || resolved == matched_dir
        body = JSON.generate({ error: 'Forbidden' })
        return ['403', STATIC_SECURITY_HEADERS.merge('Content-Type' => 'application/json'), [body]]
      end

      if File.file?(resolved) && File.readable?(resolved)
        ext = File.extname(resolved).downcase
        content_type = MIME_TYPES[ext] || 'application/octet-stream'
        content = File.binread(resolved)
        headers = STATIC_SECURITY_HEADERS.merge('Content-Type' => content_type, 'Content-Length' => content.bytesize.to_s)
        ['200', headers, [content]]
      else
        nil
      end
    end
  end
end
