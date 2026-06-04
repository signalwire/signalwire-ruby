# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'openssl'
require 'rack'
require_relative '../logging'
require_relative 'document'
require_relative 'schema'

module SignalWire
  module SWML
    class Service
      # Python parity:
      # - ``name``, ``route``, ``host``, ``port`` — surface from
      #   SWMLService.
      # - ``schema_path`` — path to the SWML schema file (or nil to use
      #   the gem-bundled default).
      # - ``config_file`` — optional TOML/YAML config file path.
      # - ``schema_validation`` — boolean flag mirroring Python's
      #   ``self._schema_validation``. ``SWML_SKIP_SCHEMA_VALIDATION=1``
      #   env var forces this to false.
      attr_reader :name, :route, :host, :port,
                  :schema_path, :config_file, :schema_validation

      # @param name   [String]  Human-readable service name
      # @param route  [String]  HTTP path this service responds on (default "/")
      # @param host   [String]  Bind address (default "0.0.0.0")
      # @param port   [Integer, nil] Port — falls back to $PORT then 3000
      # @param basic_auth [Array(String,String), nil] Explicit (user, pass) pair
      # Maximum request body size enforced on /swaig and the main route (1 MB).
      SWAIG_FN_NAME = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/.freeze

      def initialize(name:, route: '/', host: '0.0.0.0', port: nil, basic_auth: nil,
                     schema_path: nil, config_file: nil, schema_validation: true)
        @name   = name
        @route  = route.chomp('/')
        @route  = '/' if @route.empty?
        @host   = host
        @port   = port || Integer(ENV.fetch('PORT', 3000))
        @log    = Logging.logger("SWML::Service[#{name}]")
        @document = Document.new
        @routing_callbacks = {}
        @server = nil

        # Python parity:
        # - ``schema_path`` — explicit path to the SWML schema file.
        #   When nil we fall back to the schema bundled with the gem
        #   via SWML::Schema.
        # - ``config_file`` — TOML/YAML configuration override file
        #   (Python's ``ConfigLoader``). Ruby v1 stashes the path; the
        #   loader is wired by AgentBase only when needed.
        # - ``schema_validation`` — when true (default), out-bound SWML
        #   is validated against the schema. ``SWML_SKIP_SCHEMA_VALIDATION=1``
        #   env var overrides to false (Python parity).
        @schema_path        = schema_path
        @config_file        = config_file
        @schema_validation  = schema_validation && ENV['SWML_SKIP_SCHEMA_VALIDATION'] != '1'

        # SWAIG tool registry — lifted from AgentBase so any Service (sidecar,
        # non-agent verb host) can register and dispatch SWAIG functions.
        @tools = {}            # name => { definition + handler }
        @swaig_functions = {}  # name => raw hash (DataMap etc.)

        # --- auth --------------------------------------------------------
        @basic_auth = if basic_auth
                        basic_auth
                      elsif ENV['SWML_BASIC_AUTH_USER'] && ENV['SWML_BASIC_AUTH_PASSWORD']
                        [ENV['SWML_BASIC_AUTH_USER'], ENV['SWML_BASIC_AUTH_PASSWORD']]
                      else
                        [SecureRandom.uuid, SecureRandom.uuid]
                      end

        # --- SSL/TLS (server) -------------------------------------------
        # Python parity (SecurityConfig.load_from_env): the server can be
        # told to serve HTTPS via three env vars, consumed by +serve+ /
        # +AgentBase#serve+ to bind WEBrick with SSLEnable. Explicit
        # +serve(ssl_cert:, ssl_key:, ssl_enabled:)+ kwargs still override
        # these at call time.
        #   SWML_SSL_ENABLED   — "true"/"1"/"yes" (case-insensitive) → on
        #   SWML_SSL_CERT_PATH — PEM certificate path
        #   SWML_SSL_KEY_PATH  — PEM private-key path
        @ssl_enabled   = %w[true 1 yes].include?(ENV['SWML_SSL_ENABLED'].to_s.strip.downcase)
        @ssl_cert_path = ENV['SWML_SSL_CERT_PATH']
        @ssl_key_path  = ENV['SWML_SSL_KEY_PATH']
        @domain        = ENV['SWML_DOMAIN']

        @log.info "Service '#{@name}' initialised (route=#{@route}, port=#{@port})"
      end

      # ------------------------------------------------------------------
      # SWAIG tool registry (lifted from AgentBase)
      # ------------------------------------------------------------------

      # Define a SWAIG function the AI can call. Tool descriptions and
      # parameter descriptions are LLM-facing prompt engineering — see
      # PORTING_GUIDE for guidance.
      def define_tool(name:, description:, parameters: {}, secure: false, &handler)
        @tools[name] = {
          definition: {
            'function'    => name,
            'description' => description,
            'parameters'  => parameters,
          },
          handler:    handler,
          secure:     secure,
        }
        self
      end

      # Register a raw SWAIG function definition (e.g. from DataMap#to_swaig_function).
      def register_swaig_function(func_def)
        fname = func_def['function'] || func_def[:function]
        return self unless fname
        @swaig_functions[fname] = func_def.transform_keys(&:to_s)
        self
      end

      # Return an array of all tool definitions (for SWML rendering).
      def define_tools
        defs = @tools.values.map { |t| t[:definition].dup }
        defs + @swaig_functions.values.map(&:dup)
      end

      # Dispatch a function call to the registered handler. Default plain
      # implementation — AgentBase overrides with token validation.
      def on_function_call(name, args, raw_data)
        tool = @tools[name]
        return nil unless tool && tool[:handler]
        result = tool[:handler].call(args, raw_data)
        if result.is_a?(Hash)
          result
        elsif result.respond_to?(:to_h) && !result.nil?
          result.to_h
        else
          { 'response' => result.to_s }
        end
      end

      # List registered SWAIG tool names in registration order.
      def list_tool_names
        @tools.keys
      end

      # Whether a SWAIG function with the given name is registered.
      # (Python parity: ToolRegistry#has_function.)
      # @!visibility private  (idiomatic alias: #function?; original kept for
      #   cross-port audit parity + back-compat)
      def has_function(name)
        @tools.key?(name) || @swaig_functions.key?(name)
      end

      # --- Idiomatic Ruby accessors/predicates (additive aliases) ---
      # def-wrappers (not alias_method) so placement is independent of where
      # the get_* target is defined in the class body.
      def all_functions = get_all_functions
      def basic_auth_credentials_with_source = get_basic_auth_credentials_with_source
      # Ruby `?`-predicate form of has_function.
      def function?(name) = has_function(name)

      # Get a registered SWAIG function by name, or nil when absent.
      # (Python parity: ToolRegistry#get_function.)
      def get_function(name)
        @tools[name] || @swaig_functions[name]
      end

      # Snapshot of all registered SWAIG functions keyed by name.
      # (Python parity: ToolRegistry#get_all_functions.)
      # @!visibility private  (idiomatic alias: #all_functions; original kept
      #   for cross-port audit parity + back-compat)
      def get_all_functions
        out = {}
        @tools.each { |k, v| out[k] = v }
        @swaig_functions.each { |k, v| out[k] = v }
        out
      end

      # Remove a registered SWAIG function. Returns true on success,
      # false when the function was not registered.
      # (Python parity: ToolRegistry#remove_function.)
      def remove_function(name)
        if @tools.key?(name)
          @tools.delete(name)
          true
        elsif @swaig_functions.key?(name)
          @swaig_functions.delete(name)
          true
        else
          false
        end
      end

      # Extension point: invoked between argument parsing and function
      # dispatch on POST /swaig. Returns [target, short_circuit]. If
      # short_circuit is non-nil, it's returned as the SWAIG response
      # without calling on_function_call. AgentBase overrides to add
      # session-token validation and ephemeral dynamic-config copies.
      def swaig_pre_dispatch(_request_data, _func_name, _env)
        [self, nil]
      end

      # Extension point: handle GET /swaig (returns the SWML document by
      # default). AgentBase overrides to render with prompts + dynamic config.
      def render_main_swml(_request_data = nil, request: nil)
        @document.to_h
      end

      # Extension point: register additional Rack routes after Service
      # mounts /health, /ready, /swaig, and the main route. AgentBase uses
      # this to add /post_prompt, /debug_events, /mcp.
      #
      # @param sub_path [String] The sub-path under the main route
      # @param request_data [Hash, nil] Parsed JSON body
      # @param env [Hash] The Rack env
      # @return [Array, nil] A Rack response triple, or nil if not handled
      def handle_additional_route(_sub_path, _request_data, _env)
        nil
      end

      # ------------------------------------------------------------------
      # Verb auto-vivification via method_missing
      # ------------------------------------------------------------------

      def method_missing(method_name, *args, **kwargs)
        verb = method_name.to_s

        if SWML.schema.valid_verb?(verb)
          execute_verb(verb, args, kwargs)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        SWML.schema.valid_verb?(method_name.to_s) || super
      end

      # Execute a SWML verb, adding it to the current document.
      #
      # For most verbs the config is a keyword-args Hash.
      # The +sleep+ verb is special: it also accepts a bare Integer.
      def execute_verb(verb_name, args = [], kwargs = {})
        verb_name = verb_name.to_s

        if verb_name == 'sleep'
          # Accept sleep(2000) or sleep(duration: 2000)
          value = if args.length == 1 && args.first.is_a?(Integer)
                    args.first
                  elsif kwargs.key?(:duration)
                    kwargs[:duration]
                  elsif !kwargs.empty?
                    kwargs.values.first
                  else
                    raise ArgumentError, "sleep requires an integer duration"
                  end
          @document.add_verb(verb_name, value)
        else
          config = kwargs.transform_keys(&:to_s).reject { |_, v| v.nil? }
          @document.add_verb(verb_name, config)
        end
      end

      # ------------------------------------------------------------------
      # Auth helpers
      # ------------------------------------------------------------------

      # Get the configured basic-auth credentials.
      #
      # Python parity: ``get_basic_auth_credentials(include_source=False)``.
      # When ``include_source`` is true, returns a 3-tuple ``[user,
      # pass, source]`` where ``source`` is one of ``"environment"``,
      # ``"auto-generated"``, or ``"provided"``. Otherwise returns the
      # 2-tuple ``[user, pass]``.
      #
      # @param include_source [Boolean]
      # @return [Array(String, String)] or [Array(String, String, String)]
      def get_basic_auth_credentials(include_source: false)
        u, p = @basic_auth
        return [u, p] unless include_source

        env_user = ENV['SWML_BASIC_AUTH_USER']
        env_pass = ENV['SWML_BASIC_AUTH_PASSWORD']
        source =
          if env_user && !env_user.empty? && env_pass && !env_pass.empty? && u == env_user && p == env_pass
            'environment'
          elsif u&.start_with?('user_') && p && p.length > 20
            'auto-generated'
          else
            'provided'
          end
        [u, p, source]
      end

      # Validate provided basic-auth credentials against the configured ones
      # using a constant-time comparison.
      # Python parity: AuthMixin#validate_basic_auth(username, password).
      def validate_basic_auth(username, password)
        require 'openssl'
        u, p = @basic_auth
        return false if u.nil? || p.nil?
        OpenSSL.fixed_length_secure_compare(username, u) &&
          OpenSSL.fixed_length_secure_compare(password, p)
      rescue ArgumentError
        # fixed_length_secure_compare raises on length mismatch
        false
      end

      # Backwards-compat alias for the legacy 3-tuple-only form.
      # @return [Array(String, String, String)]
      # @!visibility private  (idiomatic alias: #basic_auth_credentials_with_source;
      #   original kept for cross-port audit parity + back-compat)
      def get_basic_auth_credentials_with_source
        get_basic_auth_credentials(include_source: true)
      end

      # Build the full URL for this service.
      #
      #   get_full_url                       # => "http://0.0.0.0:3000/"
      #   get_full_url(include_auth: true)   # => "http://user:pass@0.0.0.0:3000/"
      def get_full_url(include_auth: false)
        scheme = 'http'
        auth   = include_auth ? "#{@basic_auth[0]}:#{@basic_auth[1]}@" : ''
        path   = @route == '/' ? '/' : @route
        "#{scheme}://#{auth}#{@host}:#{@port}#{path}"
      end

      # ------------------------------------------------------------------
      # Routing callbacks & request handling
      # ------------------------------------------------------------------

      def register_routing_callback(path, &block)
        @routing_callbacks[path] = block
      end

      # Customization hook called when SWML is requested. Default
      # delegates to {#on_swml_request} and returns its result.
      # Subclasses typically override +on_swml_request+ rather than
      # this method.
      #
      # Return +nil+ to use the default SWML rendering, or a Hash of
      # modifications to merge into the document.
      #
      # Python parity: WebMixin#on_request(request_data, callback_path).
      # The Python third +request+ argument is FastAPI-specific and
      # intentionally not mirrored.
      # Python parity: ``on_request(request_data, callback_path)``. The
      # third Python parameter (``request``) — a FastAPI ``Request`` —
      # is propagated through Ruby as the optional ``request:`` keyword
      # so subclasses can read query/header info when a Rack-style
      # request is available. Default: delegate to ``on_swml_request``.
      def on_request(request_data = nil, callback_path = nil, request: nil)
        on_swml_request(request_data, callback_path, request: request)
      end

      # Customization point for subclasses to modify SWML based on
      # request data. The default returns nil (no modification).
      #
      # Python parity:
      # ``on_swml_request(request_data, callback_path, request)``. The
      # ``request:`` keyword carries the Rack request (or FastAPI
      # ``Request`` analogue) for subclasses that need query params
      # or headers.
      def on_swml_request(request_data = nil, callback_path = nil, request: nil)
        nil
      end

      # ------------------------------------------------------------------
      # Render the current SWML document
      # ------------------------------------------------------------------

      def render
        @document.render
      end

      def render_pretty
        @document.render_pretty
      end

      # Expose the underlying document (useful for tests and subclasses).
      def document
        @document
      end

      # SchemaUtils helper bound to this Service. Mirrors Python's
      # self.schema_utils public instance attribute on SWMLService.
      # Built lazily on first access.
      def schema_utils
        @schema_utils ||= begin
          require_relative '../utils/schema_utils'
          ::SignalWire::Utils::SchemaUtils.new
        end
      end

      # ------------------------------------------------------------------
      # Rack interface
      # ------------------------------------------------------------------

      # Returns a Rack-compatible application.
      def rack_app
        @rack_app ||= build_rack_app
      end

      # Start serving (blocking).
      #
      # Python parity:
      # ``serve(host=None, port=None, ssl_cert=None, ssl_key=None,
      # ssl_enabled=None, domain=None)``. When SSL parameters are
      # supplied the server is started with HTTPS bindings; otherwise
      # plain HTTP. ``host``/``port`` overrides default to the
      # constructor-provided values.
      #
      # @param host [String, nil] override bind host
      # @param port [Integer, nil] override bind port
      # @param ssl_cert [String, nil] PEM cert path
      # @param ssl_key [String, nil] PEM key path
      # @param ssl_enabled [Boolean, nil] explicit SSL enable
      # @param domain [String, nil] domain for SSL config
      def serve(host: nil, port: nil, ssl_cert: nil, ssl_key: nil,
                ssl_enabled: nil, domain: nil)
        require 'webrick'

        bind_host = host || @host
        bind_port = port || @port

        if !ssl_enabled.nil?
          @ssl_enabled = ssl_enabled
        end
        @domain = domain if domain
        @ssl_cert_path = ssl_cert if ssl_cert
        @ssl_key_path  = ssl_key  if ssl_key

        @log.info "Starting server on #{bind_host}:#{bind_port} ..."

        user, _pass = @basic_auth
        @log.info "Basic-auth credentials — user: #{user}  password: [REDACTED]"

        webrick_opts = {
          Host: bind_host,
          Port: bind_port,
          Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
          AccessLog: []
        }

        _apply_webrick_ssl!(webrick_opts)

        @server = ::WEBrick::HTTPServer.new(**webrick_opts)

        # Rack 3+ moved Handler to the rackup gem.
        handler = begin
                    require 'rackup/handler/webrick'
                    Rackup::Handler::WEBrick
                  rescue LoadError
                    require 'rack/handler/webrick'
                    Rack::Handler::WEBrick
                  end
        @server.mount '/', handler, rack_app

        trap('INT')  { stop }
        trap('TERM') { stop }

        @server.start
      end

      # Gracefully stop the server.
      def stop
        @server&.shutdown
      end

      # ------------------------------------------------------------------
      private
      # ------------------------------------------------------------------

      # Mutate a WEBrick option hash in place to enable HTTPS when SSL is
      # configured (+@ssl_enabled+ with both a cert and key path present).
      # Loads the PEM cert + private key with the generic +OpenSSL::PKey.read+
      # so RSA and EC keys both work. A no-op when SSL is off or incomplete,
      # so plain-HTTP serving is untouched. Shared by +SWMLService#serve+ and
      # +AgentBase#serve+ (WebMixin parity) so both code paths bind TLS
      # identically. Returns true when SSL was applied, false otherwise.
      # @api private
      def _apply_webrick_ssl!(opts)
        return false unless @ssl_enabled && @ssl_cert_path && @ssl_key_path

        require 'webrick/https'
        require 'openssl'
        opts[:SSLEnable]      = true
        opts[:SSLCertificate] = OpenSSL::X509::Certificate.new(File.read(@ssl_cert_path))
        opts[:SSLPrivateKey]  = OpenSSL::PKey.read(File.read(@ssl_key_path))
        true
      end

      # Internal request dispatcher: invoked by the rack app to produce
      # the final SWML hash for a request. Tries (in order) the
      # +on_request+ customization hook (Python WebMixin parity), then
      # any registered routing callback, then the default rendered
      # document.
      #
      # +request_data+ is the parsed JSON body (or nil). Returns the
      # SWML hash to serialise as the response.
      def dispatch_request(request_data, callback_path)
        override = on_request(request_data, callback_path)
        return override if override.is_a?(Hash) && !override.empty?

        if @routing_callbacks.key?(callback_path)
          @routing_callbacks[callback_path].call(request_data)
        else
          @document.to_h
        end
      end

      def build_rack_app
        service = self
        main_route = @route

        app = Rack::Builder.new do
          # --- public endpoints (no auth) --------------------------------
          map '/health' do
            run ->(_env) {
              body = JSON.generate({ status: 'healthy' })
              [200, { 'content-type' => 'application/json' }, [body]]
            }
          end

          map '/ready' do
            run ->(_env) {
              body = JSON.generate({ status: 'ready' })
              [200, { 'content-type' => 'application/json' }, [body]]
            }
          end

          # --- authenticated endpoints -----------------------------------
          map main_route do
            use SecurityHeadersMiddleware
            use TimingSafeBasicAuth, service

            run ->(env) {
              request = Rack::Request.new(env)

              # Determine sub-path for routing callbacks / additional routes.
              sub_path = env['PATH_INFO'] || '/'
              sub_path = '/' if sub_path.empty?

              request_data = nil
              if request.post? || request.put?
                body = request.body.read
                request_data = JSON.parse(body) rescue nil
              end

              # /swaig — handled by Service itself (lifted from AgentBase).
              if sub_path == '/swaig'
                next service.send(:_handle_swaig_endpoint, request, request_data, env)
              end

              # Subclass extension hook for /post_prompt, /debug_events, /mcp, etc.
              extra = service.handle_additional_route(sub_path, request_data, env)
              next extra if extra

              # Fallback: customization hook, routing-callback, then SWML doc.
              # Call the private dispatcher via __send__ so subclass overrides
              # of on_request / on_swml_request are honoured normally.
              result = service.__send__(:dispatch_request, request_data, sub_path)
              body   = JSON.generate(result)
              [200, { 'content-type' => 'application/json' }, [body]]
            }
          end
        end

        app
      end

      # Internal: handle GET/POST /swaig.
      # GET — returns the rendered SWML doc via render_main_swml.
      # POST — parses {function, argument, call_id}, validates, runs the
      # swaig_pre_dispatch hook, dispatches via on_function_call.
      def _handle_swaig_endpoint(request, request_data, env)
        if request.get?
          swml = render_main_swml(request_data, request: request)
          return [200, { 'content-type' => 'application/json' }, [JSON.generate(swml)]]
        end

        unless request_data
          return [400, { 'content-type' => 'application/json' },
                  [JSON.generate('error' => 'Missing request body')]]
        end

        func_name = request_data['function']
        if func_name.nil? || func_name.empty?
          return [400, { 'content-type' => 'application/json' },
                  [JSON.generate('error' => 'Missing function name')]]
        end
        unless SWAIG_FN_NAME.match?(func_name)
          return [400, { 'content-type' => 'application/json' },
                  [JSON.generate('error' => "Invalid function name format: '#{func_name}'")]]
        end

        # Argument extraction: nested {argument:{parsed:[...]}} OR flat {arguments}
        args = {}
        if request_data['argument'].is_a?(Hash)
          parsed = request_data['argument']['parsed']
          args = parsed.first if parsed.is_a?(Array) && !parsed.empty?
        elsif request_data['arguments'].is_a?(Hash)
          args = request_data['arguments']
        end
        args ||= {}

        target, short_circuit = swaig_pre_dispatch(request_data, func_name, env)
        if short_circuit
          return [200, { 'content-type' => 'application/json' }, [JSON.generate(short_circuit)]]
        end

        result = target.on_function_call(func_name, args, request_data)
        if result.nil?
          return [404, { 'content-type' => 'application/json' },
                  [JSON.generate('error' => "Unknown function: #{func_name}")]]
        end
        [200, { 'content-type' => 'application/json' }, [JSON.generate(result)]]
      end

      # ------------------------------------------------------------------
      # Middleware: security headers
      # ------------------------------------------------------------------
      class SecurityHeadersMiddleware
        HEADERS = {
          'x-content-type-options' => 'nosniff',
          'x-frame-options'        => 'DENY',
          'cache-control'          => 'no-store, no-cache, must-revalidate'
        }.freeze

        def initialize(app)
          @app = app
        end

        def call(env)
          status, headers, body = @app.call(env)
          HEADERS.each { |k, v| headers[k] = v }
          [status, headers, body]
        end
      end

      # ------------------------------------------------------------------
      # Middleware: timing-safe Basic-Auth
      # ------------------------------------------------------------------
      class TimingSafeBasicAuth
        def initialize(app, service)
          @app     = app
          @service = service
        end

        def call(env)
          auth = Rack::Auth::Basic::Request.new(env)

          unless auth.provided? && auth.basic?
            return unauthorized
          end

          user, pass = @service.get_basic_auth_credentials
          input_user, input_pass = auth.credentials

          # Timing-safe comparison to prevent timing attacks.
          user_ok = secure_compare(user, input_user)
          pass_ok = secure_compare(pass, input_pass)

          if user_ok && pass_ok
            @app.call(env)
          else
            unauthorized
          end
        end

        private

        def unauthorized
          body = 'Unauthorized'
          [
            401,
            {
              'content-type'     => 'text/plain',
              'www-authenticate' => 'Basic realm="SignalWire SWML Service"'
            },
            [body]
          ]
        end

        # Rack::Utils.secure_compare performs a constant-time byte comparison.
        def secure_compare(a, b)
          Rack::Utils.secure_compare(a.to_s, b.to_s)
        end
      end
    end
  end
end
