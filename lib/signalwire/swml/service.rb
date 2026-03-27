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
      attr_reader :name, :route, :host, :port

      # @param name   [String]  Human-readable service name
      # @param route  [String]  HTTP path this service responds on (default "/")
      # @param host   [String]  Bind address (default "0.0.0.0")
      # @param port   [Integer, nil] Port — falls back to $PORT then 3000
      # @param basic_auth [Array(String,String), nil] Explicit (user, pass) pair
      def initialize(name:, route: '/', host: '0.0.0.0', port: nil, basic_auth: nil)
        @name   = name
        @route  = route.chomp('/')
        @route  = '/' if @route.empty?
        @host   = host
        @port   = port || Integer(ENV.fetch('PORT', 3000))
        @log    = Logging.logger("SWML::Service[#{name}]")
        @document = Document.new
        @routing_callbacks = {}
        @server = nil

        # --- auth --------------------------------------------------------
        @basic_auth = if basic_auth
                        basic_auth
                      elsif ENV['SWML_BASIC_AUTH_USER'] && ENV['SWML_BASIC_AUTH_PASSWORD']
                        [ENV['SWML_BASIC_AUTH_USER'], ENV['SWML_BASIC_AUTH_PASSWORD']]
                      else
                        [SecureRandom.uuid, SecureRandom.uuid]
                      end

        @log.info "Service '#{@name}' initialised (route=#{@route}, port=#{@port})"
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

      # Returns [username, password]
      def get_basic_auth_credentials
        @basic_auth.dup
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

      # Called when a request arrives at the service's route.
      # +request_data+ is the parsed JSON body (or nil).
      # Returns the SWML hash to serialise as the response.
      def on_request(request_data, callback_path)
        if @routing_callbacks.key?(callback_path)
          @routing_callbacks[callback_path].call(request_data)
        else
          @document.to_h
        end
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

      # ------------------------------------------------------------------
      # Rack interface
      # ------------------------------------------------------------------

      # Returns a Rack-compatible application.
      def rack_app
        @rack_app ||= build_rack_app
      end

      # Start serving (blocking).
      def serve
        require 'webrick'
        @log.info "Starting server on #{@host}:#{@port} ..."

        user, _pass = @basic_auth
        @log.info "Basic-auth credentials — user: #{user}  password: [REDACTED]"

        @server = ::WEBrick::HTTPServer.new(
          Host: @host,
          Port: @port,
          Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
          AccessLog: []
        )

        @server.mount '/', Rack::Handler::WEBrick, rack_app

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

              # Determine sub-path for routing callbacks
              callback_path = env['PATH_INFO'] || '/'
              callback_path = '/' if callback_path.empty?

              request_data = nil
              if request.post? || request.put?
                body = request.body.read
                request_data = JSON.parse(body) rescue nil
              end

              result = service.on_request(request_data, callback_path)
              body   = JSON.generate(result)
              [200, { 'content-type' => 'application/json' }, [body]]
            }
          end
        end

        app
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
