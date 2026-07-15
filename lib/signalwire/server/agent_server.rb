# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'json'
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

    # Public Rack application — the cached Rack app (a Proc) so callers
    # can mount it on their own server or pass it to Rack-compatible test
    # harnesses.
    def app
      return @app if defined?(@app)

      @app = rack_app
    end

    # MIME types for static file serving.
    MIME_TYPES = {
      '.html' => 'text/html',
      '.htm' => 'text/html',
      '.css' => 'text/css',
      '.js' => 'application/javascript',
      '.json' => 'application/json',
      '.png' => 'image/png',
      '.jpg' => 'image/jpeg',
      '.jpeg' => 'image/jpeg',
      '.gif' => 'image/gif',
      '.svg' => 'image/svg+xml',
      '.ico' => 'image/x-icon',
      '.txt' => 'text/plain',
      '.xml' => 'application/xml',
      '.woff' => 'font/woff',
      '.woff2' => 'font/woff2',
      '.ttf' => 'font/ttf',
      '.eot' => 'application/vnd.ms-fontobject',
      '.map' => 'application/json',
      '.webp' => 'image/webp',
      '.pdf' => 'application/pdf'
    }.freeze

    # Security headers applied to static file responses.
    STATIC_SECURITY_HEADERS = {
      'x-content-type-options' => 'nosniff',
      'x-frame-options' => 'DENY',
      'cache-control' => 'no-store, no-cache, must-revalidate'
    }.freeze

    # Construct an AgentServer.
    #
    # ``log_level`` controls the AgentServer's logger verbosity, mapped
    # through ``SignalWire::Logging.logger`` to the standard
    # WARN/INFO/DEBUG levels.
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
      @agents = {} # route => agent object
      @sip_routes = {} # username => route
      @static_routes = {} # route => directory
      @mutex  = Mutex.new

      @logger = Logging.logger('AgentServer')
      apply_log_level(@logger, @log_level)
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
    def apply_log_level(logger, level)
      require 'logger'
      mapped = map_log_level(level)
      set_logger_level(logger, mapped)
      mapped
    rescue StandardError
      begin
        ::Logger::INFO
      rescue StandardError
        nil
      end
    end

    # @api private
    # Apply +mapped+ to +logger+. SignalWire::Logging::Logger doesn't expose
    # level=; attach via instance_variable (plus a singleton reader) so .level
    # reads return the mapped value.
    def set_logger_level(logger, mapped)
      if logger.respond_to?(:level=)
        logger.level = mapped
      else
        logger.instance_variable_set(:@level, mapped)
        logger.define_singleton_method(:level) { @level } unless logger.respond_to?(:level)
      end
    end

    # Map a Python-style log level string to a ::Logger constant.
    # 'info' and the else fallback both map to INFO; the explicit 'info' arm
    # documents it as a known level rather than an unrecognized default.
    # @api private
    def map_log_level(level)
      case level
      when 'debug'             then ::Logger::DEBUG
      when 'info'              then ::Logger::INFO
      when 'warning', 'warn'   then ::Logger::WARN
      when 'error'             then ::Logger::ERROR
      when 'critical', 'fatal' then ::Logger::FATAL
      else ::Logger::INFO
      end
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
          @agents.each_key do |r|
            username = r.sub(%r{^/}, '').tr('/', '_')
            @sip_routes[username] = r
          end
        end
      end
      self
    end

    # Register a routing callback across all agents.
    #
    # Adds unified routing logic to every registered agent at the same
    # path. The +path+ is normalized (leading slash ensured, trailing
    # slash stripped) and the callback is registered on each agent that
    # exposes +register_routing_callback+.
    #
    # The callback may be supplied either as a Ruby block or as a
    # callable (Proc/lambda) +callback_fn+ positional argument.
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
    #
    # The username is lower-cased before storage (the mapping is
    # case-insensitive), and the route is normalized (leading slash
    # ensured, trailing slash stripped).
    def register_sip_username(username, route)
      route = "/#{route}" unless route.start_with?('/')
      route = route.chomp('/')
      @mutex.synchronize { @sip_routes[username.to_s.downcase] = route }
      self
    end

    # Look up the route registered for a SIP username (case-insensitive).
    # Returns the route or nil.
    def _lookup_sip_route(username)
      @mutex.synchronize { @sip_routes[username.to_s.downcase] }
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
    #   — invokes ``handle_lambda_request(event, context)`` and
    #   returns the Lambda response Hash.
    # - **CGI mode** (``GATEWAY_INTERFACE`` env var present) — invokes
    #   ``handle_cgi_request`` and returns the CGI response String.
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
        handle_lambda_request(event, context)
      when 'cgi'
        handle_cgi_request
      else
        run_server(host, port)
      end
    end

    # @api private
    def _detect_execution_mode
      return 'lambda' if ENV['AWS_LAMBDA_FUNCTION_NAME'] && !ENV['AWS_LAMBDA_FUNCTION_NAME'].empty?
      return 'cgi'    if ENV['GATEWAY_INTERFACE']

      'server'
    end

    # @api private
    def run_server(host = nil, port = nil)
      bind_host = host || @host
      bind_port = port || @port
      server = build_webrick(bind_host, bind_port)
      server.mount('/', Rack::Handler::WEBrick, rack_app) if defined?(Rack::Handler::WEBrick)
      trap('INT') { server.shutdown }
      trap('TERM') { server.shutdown }
      @logger&.info("AgentServer starting on #{bind_host}:#{bind_port}")
      server.start
    end

    # @api private
    def build_webrick(bind_host, bind_port)
      require 'webrick'
      WEBrick::HTTPServer.new(
        Host: bind_host,
        Port: bind_port,
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
        AccessLog: []
      )
    end

    # @api private
    # Handle a CGI request. Reads ``PATH_INFO``, dispatches to the
    # matching agent, and returns a CGI-formatted response string.
    def handle_cgi_request
      require 'stringio'
      env = {
        'PATH_INFO' => (ENV['PATH_INFO'] || '').strip,
        'REQUEST_METHOD' => ENV['REQUEST_METHOD'] || 'GET',
        'QUERY_STRING' => ENV['QUERY_STRING'] || '',
        'rack.input' => StringIO.new(''),
        'rack.errors' => $stderr
      }
      status, headers, body = rack_app.call(env)
      format_cgi_response(status, headers, body_to_string(body))
    end

    # @api private
    # Render a Rack triple as a CGI response string.
    def format_cgi_response(status, headers, body_str)
      out = "Status: #{status}\r\n"
      headers.each { |k, v| out << "#{k}: #{v}\r\n" }
      out << "\r\n"
      out << body_str
      out
    end

    # @api private
    # Collapse a Rack response body (Array or other) into a String.
    def body_to_string(body)
      body.respond_to?(:join) ? body.join : body.to_s
    end

    # @api private
    # Handle a Lambda invocation event. Translates the Lambda event
    # shape into a Rack env, dispatches, and returns a Lambda
    # response Hash (statusCode/headers/body).
    def handle_lambda_request(event, _context)
      require 'stringio'
      status, headers, response_body = rack_app.call(lambda_env(event || {}))
      {
        'statusCode' => Integer(status),
        'headers' => headers,
        'body' => body_to_string(response_body)
      }
    end

    # @api private
    # Translate a Lambda event Hash into a Rack env.
    def lambda_env(event)
      {
        'PATH_INFO' => lambda_path(event),
        'REQUEST_METHOD' => lambda_method(event),
        'QUERY_STRING' => '',
        'rack.input' => StringIO.new(event['body'] || ''),
        'rack.errors' => $stderr
      }
    end

    # @api private
    def lambda_path(event)
      event['path'] || event['rawPath'] || event['pathParameters']&.dig('proxy') || '/'
    end

    # @api private
    def lambda_method(event)
      event['httpMethod'] || event.dig('requestContext', 'http', 'method') || 'GET'
    end

    # Build a Rack application that routes requests to the appropriate agent.
    # @return [Proc] a Rack-compatible app
    def rack_app
      agents = @agents
      static_routes = @static_routes
      server        = self

      proc { |env| server._dispatch_request(env, agents, static_routes) }
    end

    # @api private
    # Route a single Rack request: health/root JSON endpoints, then static
    # files, then the longest-prefix-matched agent (404 when none match).
    def _dispatch_request(env, agents, static_routes)
      path = env['PATH_INFO'] || '/'

      case path
      when '/health', '/healthz'
        json_response('200', { status: 'ok', agents: agents.keys })
      when '/'
        json_response('200', root_payload(agents))
      else
        try_serve_static(path, static_routes) || dispatch_agent(env, path, agents)
      end
    end

    # @api private
    def root_payload(agents)
      {
        service: 'SignalWire Agent Server',
        agents: agents.keys,
        version: defined?(SignalWire::VERSION) ? SignalWire::VERSION : '1.0.0'
      }
    end

    # @api private
    # Dispatch to the agent whose registered route is the longest prefix of
    # +path+, or a 404 JSON response when nothing matches.
    def dispatch_agent(env, path, agents)
      matched_route, agent = match_agent(path, agents)
      return json_response('404', { error: 'Not found', path: path }) unless agent

      invoke_agent(agent, matched_route, env)
    end

    # @api private
    # Invoke a matched agent: prefer #call, then #rack_app, else a stub
    # "registered" response.
    def invoke_agent(agent, matched_route, env)
      if agent.respond_to?(:call)
        agent.call(env)
      elsif agent.respond_to?(:rack_app)
        agent.rack_app.call(env)
      else
        json_response('200', { agent: matched_route, status: 'registered' })
      end
    end

    # @api private
    # Longest-prefix match of +path+ against registered agent routes.
    # @return [Array(String, Object)] [matched_route, agent] or [nil, nil].
    def match_agent(path, agents)
      matched_route = nil
      agent = nil
      agents.each do |route, a|
        next unless _route_matches?(path, route)
        next unless matched_route.nil? || route.length > matched_route.length

        matched_route = route
        agent = a
      end
      [matched_route, agent]
    end

    # @api private
    # True when +path+ equals +route+ or sits directly under it.
    def _route_matches?(path, route)
      path == route || path.start_with?("#{route}/")
    end

    # @api private
    # Build a Rack JSON response triple from a status and a Hash payload.
    def json_response(status, payload)
      [status, { 'Content-Type' => 'application/json' }, [payload.to_json]]
    end

    # @api private
    # Attempt to serve a static file. Returns a Rack response or nil.
    def try_serve_static(path, static_routes)
      matched_route, matched_dir = match_static_route(path, static_routes)
      return nil unless matched_dir

      relative = static_relative_path(path, matched_route)
      # Path traversal protection: reject any path containing "..".
      return static_forbidden if relative.include?('..')

      resolved = File.expand_path(File.join(matched_dir, relative))
      # Ensure resolved path is still under the served directory.
      return static_forbidden unless _under_directory?(resolved, matched_dir)
      return unless File.file?(resolved) && File.readable?(resolved)

      static_file_response(resolved)
    end

    # @api private
    # Relative path after the route prefix, defaulting to /index.html.
    def static_relative_path(path, matched_route)
      relative = path.sub(matched_route, '')
      relative.empty? || relative == '/' ? '/index.html' : relative
    end

    # @api private
    def _under_directory?(resolved, directory)
      resolved.start_with?("#{directory}/") || resolved == directory
    end

    # @api private
    # Longest-prefix match of +path+ against the static route prefixes.
    # @return [Array(String, String)] [matched_route, directory] or [nil, nil].
    def match_static_route(path, static_routes)
      matched_route = nil
      matched_dir   = nil
      static_routes.each do |route, directory|
        next unless _route_matches?(path, route)
        next unless matched_route.nil? || route.length > matched_route.length

        matched_route = route
        matched_dir   = directory
      end
      [matched_route, matched_dir]
    end

    # @api private
    def static_forbidden
      body = JSON.generate({ error: 'Forbidden' })
      ['403', STATIC_SECURITY_HEADERS.merge('Content-Type' => 'application/json'), [body]]
    end

    # @api private
    # Read a resolved file and build its Rack response with MIME + security headers.
    def static_file_response(resolved)
      ext = File.extname(resolved).downcase
      content_type = MIME_TYPES[ext] || 'application/octet-stream'
      content = File.binread(resolved)
      headers = STATIC_SECURITY_HEADERS.merge('Content-Type' => content_type,
                                              'Content-Length' => content.bytesize.to_s)
      ['200', headers, [content]]
    end

    # Internal helpers (formerly leading-underscore by convention). Not part of
    # the public/Python surface — declared private so the cross-port surface
    # enumerator continues to exclude them.
    private :apply_log_level, :set_logger_level, :map_log_level,
            :run_server, :build_webrick, :handle_cgi_request, :format_cgi_response,
            :body_to_string, :handle_lambda_request, :lambda_env, :lambda_path,
            :lambda_method, :root_payload, :dispatch_agent, :invoke_agent, :match_agent,
            :json_response, :try_serve_static, :static_relative_path, :match_static_route,
            :static_forbidden, :static_file_response
  end
end
