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
    # rubocop:disable Metrics/ClassLength -- one Python class (SWMLService): the
    # full public surface (tool registry, auth helpers, verb auto-vivification,
    # Rack serving) plus the two nested Rack middleware classes must live together;
    # splitting breaks the 1:1 surface mapping to the reference.
    class Service
      # Attributes:
      # - ``name``, ``route``, ``host``, ``port`` — service identity and
      #   bind configuration.
      # - ``schema_path`` — path to the SWML schema file (or nil to use
      #   the gem-bundled default).
      # - ``config_file`` — optional TOML/YAML config file path.
      # - ``schema_validation`` — boolean flag controlling out-bound SWML
      #   schema validation. ``SWML_SKIP_SCHEMA_VALIDATION=1`` env var
      #   forces this to false.
      attr_reader :name, :route, :host, :port,
                  :schema_path, :config_file, :schema_validation

      # @param name   [String]  Human-readable service name
      # @param route  [String]  HTTP path this service responds on (default "/")
      # @param host   [String]  Bind address (default "0.0.0.0")
      # @param port   [Integer, nil] Port — falls back to $PORT then 3000
      # @param basic_auth [Array(String,String), nil] Explicit (user, pass) pair
      # Maximum request body size enforced on /swaig and the main route (1 MB).
      SWAIG_FN_NAME = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/

      def initialize(name:, route: '/', host: '0.0.0.0', port: nil, basic_auth: nil,
                     schema_path: nil, config_file: nil, schema_validation: true)
        @name   = name
        @route  = normalize_route(route)
        @host   = host
        @port   = port || Integer(ENV.fetch('PORT', 3000))
        @log    = Logging.logger("SWML::Service[#{name}]")

        init_document_state
        init_schema_config(schema_path, config_file, schema_validation)
        @basic_auth = resolve_service_basic_auth(basic_auth)
        init_ssl_config

        @log.info "Service '#{@name}' initialised (route=#{@route}, port=#{@port})"
      end

      # ------------------------------------------------------------------
      # SWAIG tool registry (lifted from AgentBase)
      # ------------------------------------------------------------------

      # Define a SWAIG function the AI can call. Tool descriptions and
      # parameter descriptions are LLM-facing prompt engineering — see
      # PORTING_GUIDE for guidance.
      def define_tool(name:, description:, parameters: {}, secure: true, &handler)
        @tools[name] = {
          definition: {
            'function' => name,
            'description' => description,
            'parameters' => parameters
          },
          handler: handler,
          secure: secure
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
      # @!visibility private  (idiomatic alias: #function?; original name kept
      #   for back-compat)
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
      def get_function(name)
        @tools[name] || @swaig_functions[name]
      end

      # Snapshot of all registered SWAIG functions keyed by name.
      # @!visibility private  (idiomatic alias: #all_functions; original name
      #   kept for back-compat)
      def get_all_functions
        out = {}
        @tools.each { |k, v| out[k] = v }
        @swaig_functions.each { |k, v| out[k] = v }
        out
      end

      # Remove a registered SWAIG function. Returns true on success,
      # false when the function was not registered.
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
      # request: is part of the override signature (subclasses use it); kept here
      # for that contract even though the base no-op ignores it.
      def render_main_swml(_request_data = nil, request: nil) # rubocop:disable Lint/UnusedMethodArgument
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
          @document.add_verb(verb_name, sleep_duration(args, kwargs))
        else
          @document.add_verb(verb_name, SWML._verb_config(verb_name, args, kwargs))
        end
      end

      # ------------------------------------------------------------------
      # Auth helpers
      # ------------------------------------------------------------------

      # Get the configured basic-auth credentials.
      #
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

        [u, p, service_basic_auth_source(u, p)]
      end

      # Validate provided basic-auth credentials against the configured ones
      # using a constant-time comparison.
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
      #   original name kept for back-compat)
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

      # Register a routing callback at +path+. The path is normalized for
      # consistent lookup — trailing slash stripped, leading slash ensured
      # (so "/sip/" and "sip" both store as "/sip").
      def register_routing_callback(path, &block)
        normalized = path.to_s.chomp('/')
        normalized = "/#{normalized}" unless normalized.start_with?('/')
        @routing_callbacks[normalized] = block
      end

      # Framework-free request-dispatch core — the primitive dispatch surface
      # the SDK ports share (mirrors python
      # ``SWMLService.handle_request(method, url, headers, body)`` and dotnet's
      # ``(int, Dictionary, string) HandleRequest``). Performs proxy detection,
      # basic-auth, the routing-callback check, and the ``on_request``
      # modification hook over plain primitives instead of the Rack ``env``,
      # returning a ``[status, headers, body_string]`` triple. The Rack path
      # (+handle_main_route+) delegates here so both produce identical responses.
      #
      # @param method [String] HTTP method, e.g. "GET" / "POST".
      # @param url [String] the full request URL (proxy detection + callback path).
      # @param headers [Hash{String=>String}] request headers as a plain Hash.
      # @param body [Hash, nil] the already-parsed JSON body for POST, or nil.
      # @return [Array(Integer, Hash{String=>String}, String)]
      #   +[status_code, response_headers, body_string]+. 200 → a JSON SWML
      #   document; a routing redirect → 307 with a +Location+ header and empty
      #   body; an auth failure → 401 with a +WWW-Authenticate: Basic+ header.
      def handle_request(method, url, headers, body = nil)
        callback_path = callback_path_for_url(url)
        handle_request_core(method, url, headers, body || {}, callback_path)
      end

      # Shared decomposed dispatch logic over primitives. Both +handle_request+
      # and the Rack +handle_main_route+ delegate here so dispatch behavior has a
      # single source. Returns a +[status, headers, body_string]+ triple.
      def handle_request_core(method, url, headers, body, callback_path)
        detect_proxy_from_primitives(url, headers)
        return unauthorized_triple unless check_basic_auth_headers(headers)

        redirect = routing_redirect(method, body, headers, callback_path)
        return redirect if redirect

        modifications = on_request(body, callback_path)
        render_dispatch_triple(modifications)
      end

      # 401 triple with the standard WWW-Authenticate header.
      def unauthorized_triple
        [401, { 'WWW-Authenticate' => 'Basic' }, JSON.generate('error' => 'Unauthorized')]
      end

      # Run the routing callback for a POST with a non-empty body on a path that
      # has one registered; a non-nil return is a redirect route → 307 (preserves
      # the POST method + body). Returns the 307 triple, or nil to continue.
      def routing_redirect(method, body, headers, callback_path)
        return nil unless method == 'POST' && body && !body.empty? && callback_path
        return nil unless @routing_callbacks.key?(callback_path)

        route = invoke_routing_callback(@routing_callbacks[callback_path], body, headers)
        return nil if route.nil?

        [307, { 'Location' => route }, '']
      end

      # Invoke a routing callback with +(body, headers)+. Blocks that declare a
      # single parameter still work — arity 1 is called with +body+ only.
      # Swallows callback errors (a raising callback does not 500 the request),
      # returning nil so dispatch falls through to render.
      def invoke_routing_callback(callback, body, headers)
        if callback.arity == 1
          callback.call(body)
        else
          callback.call(body, headers)
        end
      rescue StandardError => e
        @log&.error("error_in_routing_callback: #{e.message}")
        nil
      end

      # Turn an +on_request+ modification result into the 200 SWML triple. A Hash
      # of modifications is shallow-merged over the current document; otherwise the
      # default rendered document is returned.
      def render_dispatch_triple(modifications)
        if modifications.is_a?(Hash) && !modifications.empty?
          document = get_document
          modifications.each { |k, v| document[k] = v if document.key?(k) }
          return [200, {}, JSON.generate(document)]
        end
        [200, {}, render_document]
      end

      # Derive the registered routing-callback path (if any) that +url+ targets.
      # The Rack path gets the callback path from PATH_INFO directly; the
      # primitive +handle_request+ recovers the equivalent by matching the URL's
      # normalized path against the registered callbacks.
      def callback_path_for_url(url)
        return nil if @routing_callbacks.nil? || @routing_callbacks.empty?

        path = _url_path(url)
        stripped = path.gsub(%r{\A/+|/+\z}, '')
        normalized = stripped.empty? ? path.chomp('/') : "/#{stripped}"
        @routing_callbacks.each_key do |cb_path|
          return cb_path if normalized == cb_path || normalized.end_with?(cb_path)
        end
        nil
      end

      # Extract the path component from a full URL or a bare path.
      def _url_path(url)
        if url.include?('://')
          require 'uri'
          URI.parse(url).path
        elsif url.start_with?('/')
          url.split('?', 2).first
        else
          url
        end
      rescue URI::InvalidURIError
        url
      end

      # Framework-free basic-auth check over a plain headers Hash — the primitive
      # the Rack TimingSafeBasicAuth and +handle_request+ share. Tolerates common
      # Authorization header casings.
      def check_basic_auth_headers(headers)
        username, password = decode_basic_auth(header_lookup(headers, 'Authorization'))
        return false if username.nil? || password.nil?

        validate_basic_auth(username, password)
      rescue StandardError
        false
      end

      # Decode a +Basic <base64>+ Authorization header value into a
      # +[username, password]+ pair, or +[nil, nil]+ when absent/malformed.
      def decode_basic_auth(auth)
        return [nil, nil] if auth.nil? || auth.empty?

        scheme, credentials = auth.split(' ', 2)
        return [nil, nil] unless scheme&.downcase == 'basic' && credentials

        require 'base64'
        Base64.decode64(credentials).split(':', 2)
      end

      # Framework-free proxy detection over a URL + plain headers Hash, mirroring
      # python's +detect_proxy_from_primitives+: honor an already-set proxy base,
      # else auto-configure +@proxy_url_base+ from X-Forwarded-* (then RFC-7239
      # Forwarded). No-op when neither is present.
      def detect_proxy_from_primitives(_url, headers)
        return if @proxy_url_base && !@proxy_url_base.empty?

        forwarded_host = header_lookup(headers, 'X-Forwarded-Host')
        if forwarded_host && !forwarded_host.empty?
          proto = header_lookup(headers, 'X-Forwarded-Proto') || 'http'
          @proxy_url_base = "#{proto}://#{forwarded_host}"
          return
        end

        detect_proxy_from_rfc7239(header_lookup(headers, 'Forwarded'))
      end

      # Parse an RFC-7239 +Forwarded: for=..;host=..;proto=..+ header and set the
      # proxy base from its host/proto directives.
      def detect_proxy_from_rfc7239(forwarded)
        return if forwarded.nil? || forwarded.empty?

        parts = forwarded.split(';').map(&:strip)
        host  = rfc7239_directive(parts, 'host')
        proto = rfc7239_directive(parts, 'proto') || 'http'
        @proxy_url_base = "#{proto}://#{host}" if host && !host.empty?
      end

      # Extract a single +name=value+ directive value (quotes stripped) from a
      # split RFC-7239 Forwarded header, or nil when absent.
      def rfc7239_directive(parts, name)
        prefix = "#{name}="
        parts.find { |p| p.start_with?(prefix) }&.delete_prefix(prefix)&.delete('"')
      end

      # Case-tolerant header lookup over a plain Hash (accepts the header's
      # conventional casing, its lowercase form, or the Rack HTTP_ env form).
      def header_lookup(headers, name)
        return nil unless headers.is_a?(Hash)

        headers[name] || headers[name.downcase] || headers[name.upcase] ||
          headers["HTTP_#{name.upcase.tr('-', '_')}"]
      end

      # Customization hook called when SWML is requested. Default
      # delegates to {#on_swml_request} and returns its result.
      # Subclasses typically override +on_swml_request+ rather than
      # this method.
      #
      # Return +nil+ to use the default SWML rendering, or a Hash of
      # modifications to merge into the document.
      #
      # Signature: ``on_request(request_data, callback_path)`` with an
      # optional ``request:`` keyword carrying the Rack request, so
      # subclasses can read query/header info when a Rack-style request is
      # available. Default: delegate to ``on_swml_request``.
      def on_request(request_data = nil, callback_path = nil, request: nil)
        on_swml_request(request_data, callback_path, request: request)
      end

      # Customization point for subclasses to modify SWML based on
      # request data. The default returns nil (no modification).
      #
      # Signature: ``on_swml_request(request_data, callback_path)``. The
      # ``request:`` keyword carries the Rack request for subclasses that
      # need query params or headers.
      def on_swml_request(_request_data = nil, _callback_path = nil, request: nil) # rubocop:disable Lint/UnusedMethodArgument
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
      attr_reader :document

      # ------------------------------------------------------------------
      # Document accessors — parity with Python SWMLService (item I). Thin
      # wrappers over the underlying Document so the reference method surface
      # is present on the Service directly.
      # ------------------------------------------------------------------

      # The current SWML document as a Hash. Mirrors get_document().
      def get_document
        @document.to_h
      end

      # Render the current document as a compact JSON string. Mirrors
      # render_document() (render() returns compact JSON already).
      def render_document
        @document.render
      end

      # Reset the current document to an empty state. Mirrors reset_document().
      def reset_document
        @document.reset
        self
      end

      # Add a verb to the main section of the current document. Mirrors
      # Python SWMLService.add_verb(verb_name, config).
      #
      # The +sleep+ verb accepts a bare Integer; every other verb takes a
      # config Hash. Config is validated (specialized handler if registered,
      # otherwise the schema validator) and a SchemaValidationError is raised
      # on failure. Returns true on success, false when +config+ is neither a
      # Hash nor a valid direct value.
      def add_verb(verb_name, config)
        verb_name = verb_name.to_s
        return @document.add_verb(verb_name, config) if sleep_direct?(verb_name, config)
        return false unless verb_config_valid!(verb_name, config)

        @document.add_verb(verb_name, config)
      end

      # Add a new (empty) section to the current document. Mirrors Python
      # SWMLService.add_section(section_name). Returns false if it already
      # exists, true otherwise.
      def add_section(section_name)
        @document.add_section(section_name.to_s)
      end

      # Add a verb to a specific section. Mirrors Python
      # SWMLService.add_verb_to_section(section_name, verb_name, config). The
      # +sleep+ verb accepts a bare Integer; other verbs take a config Hash
      # (validated as in {#add_verb}).
      def add_verb_to_section(section_name, verb_name, config)
        section_name = section_name.to_s
        verb_name    = verb_name.to_s

        # Parity: Python auto-creates the section if it doesn't exist.
        @document.add_section(section_name) unless @document.has_section?(section_name)

        return @document.add_verb_to_section(section_name, verb_name, config) if sleep_direct?(verb_name, config)
        return false unless verb_config_valid!(verb_name, config)

        @document.add_verb_to_section(section_name, verb_name, config)
      end

      # Register a custom verb handler with this service's registry. Mirrors
      # register_verb_handler(handler) — delegates to the VerbHandlerRegistry.
      def register_verb_handler(handler)
        verb_registry.register_handler(handler)
        self
      end

      # The lazily-built verb-handler registry bound to this service.
      def verb_registry
        return @verb_registry if defined?(@verb_registry)

        @verb_registry = ::SignalWire::SWML::VerbHandlerRegistry.new
      end

      # Whether full JSON-schema validation is active for this service.
      # Mirrors full_validation_enabled().
      def full_validation_enabled
        @schema_validation && schema_utils.full_validation_available?
      end

      # Manually set/override the proxy URL base used for webhook callbacks.
      # Mirrors manual_set_proxy_url(proxy_url).
      def manual_set_proxy_url(proxy_url)
        @proxy_url_base = proxy_url.chomp('/') if proxy_url && !proxy_url.empty?
        self
      end

      # Extract the SIP username from a parsed request body's call.to field.
      # Mirrors the staticmethod extract_sip_username(request_body): parses a
      # "sip:user@domain" (or "tel:") URI's user portion, or nil.
      def self.extract_sip_username(request_body)
        to_field = request_body.dig('call', 'to') if request_body.is_a?(Hash)
        return nil unless to_field.is_a?(String)

        # Python parity: sip: -> username before '@'; tel: -> the number;
        # otherwise the whole 'to' field is returned.
        return to_field.delete_prefix('sip:').split('@', 2).first if to_field.start_with?('sip:')
        return to_field.delete_prefix('tel:') if to_field.start_with?('tel:')

        to_field
      rescue StandardError
        nil
      end

      # Build a Rack-mountable router (app) for this service. Mirrors
      # as_router() (Python returns a FastAPI APIRouter; Ruby returns the
      # equivalent Rack app so the service can be mounted in any Rack server).
      def as_router
        rack_app
      end

      # SchemaUtils helper bound to this Service. Mirrors Python's
      # self.schema_utils public instance attribute on SWMLService.
      # Built lazily on first access.
      def schema_utils
        return @schema_utils if defined?(@schema_utils)

        require_relative '../utils/schema_utils'
        @schema_utils = ::SignalWire::Utils::SchemaUtils.new
      end

      # ------------------------------------------------------------------
      # Rack interface
      # ------------------------------------------------------------------

      # Returns a Rack-compatible application.
      def rack_app
        return @rack_app if defined?(@rack_app)

        @rack_app = build_rack_app
      end

      # Start serving (blocking).
      #
      # When SSL parameters are supplied the server is started with HTTPS
      # bindings; otherwise plain HTTP. ``host``/``port`` overrides default
      # to the constructor-provided values.
      #
      # @param host [String, nil] override bind host
      # @param port [Integer, nil] override bind port
      # @param ssl_cert [String, nil] PEM cert path
      # @param ssl_key [String, nil] PEM key path
      # @param ssl_enabled [Boolean, nil] explicit SSL enable
      # @param domain [String, nil] domain for SSL config
      def serve(host: nil, port: nil, ssl_cert: nil, ssl_key: nil,
                ssl_enabled: nil, domain: nil)
        # Suppress-run guard (ruby_R5 N1): loading an example whose last line is
        # `svc.serve` must not boot a blocking server under tooling.
        return nil if SignalWire::Runtime.suppress_run?

        require 'webrick'

        bind_host = host || @host
        bind_port = port || @port
        apply_ssl_overrides(ssl_cert: ssl_cert, ssl_key: ssl_key, ssl_enabled: ssl_enabled, domain: domain)

        @log.info "Starting server on #{bind_host}:#{bind_port} ..."
        user, _pass = @basic_auth
        @log.info "Basic-auth credentials — user: #{user}  password: [REDACTED]"

        build_server(bind_host, bind_port)
        @server.start
      end

      # Gracefully stop the server.
      def stop
        @server&.shutdown
      end

      # Static health/ready JSON triple. Class method so the no-auth lambdas in
      # +build_rack_app+ don't capture +self+. Underscore-prefixed to stay out of
      # the surface inventory (no Python counterpart on SWMLService).
      def self._status_response(status)
        [200, { 'content-type' => 'application/json' }, [JSON.generate({ status: status })]]
      end

      # Request-handling internals (formerly leading-underscore by convention).
      # Not part of the public/Python surface — declared private so the
      # cross-port surface enumerator continues to exclude them.
      private :handle_request_core, :unauthorized_triple, :routing_redirect,
              :invoke_routing_callback, :render_dispatch_triple, :callback_path_for_url,
              :check_basic_auth_headers, :decode_basic_auth, :detect_proxy_from_primitives,
              :detect_proxy_from_rfc7239, :rfc7239_directive, :header_lookup

      # ------------------------------------------------------------------
      private

      # ------------------------------------------------------------------

      # Whether this is the +sleep+ verb passed a bare Integer duration
      # (the one verb that takes a direct value instead of a config Hash).
      def sleep_direct?(verb_name, config)
        verb_name == 'sleep' && config.is_a?(Integer)
      end

      # Validate a verb config Hash (specialized handler if registered, else
      # the schema validator). Returns false and logs when +config+ is not a
      # Hash; raises SchemaValidationError when validation fails; returns true
      # when valid.
      def verb_config_valid!(verb_name, config)
        unless config.is_a?(Hash)
          @log.warn "invalid_config_type verb=#{verb_name} expected=Hash got=#{config.class}"
          return false
        end

        is_valid, errors = validate_verb_config(verb_name, config)
        raise ::SignalWire::Utils::SchemaValidationError.new(verb_name, errors) unless is_valid

        true
      end

      # Run the verb config through a registered specialized handler when one
      # exists, otherwise the schema validator. Returns [is_valid, errors].
      def validate_verb_config(verb_name, config)
        if verb_registry.has_handler(verb_name)
          verb_registry.get_handler(verb_name).validate_config(config)
        else
          schema_utils.validate_verb(verb_name, config)
        end
      end

      # Construct the WEBrick server, mount the Rack app, and install the
      # INT/TERM shutdown traps.
      def build_server(bind_host, bind_port)
        @server = ::WEBrick::HTTPServer.new(**service_webrick_opts(bind_host, bind_port))
        @server.mount '/', service_webrick_handler, rack_app
        trap('INT')  { stop }
        trap('TERM') { stop }
      end

      # Apply explicit serve() SSL/domain kwargs over the env-derived defaults.
      def apply_ssl_overrides(ssl_cert:, ssl_key:, ssl_enabled:, domain:)
        @ssl_enabled = ssl_enabled unless ssl_enabled.nil?
        @domain = domain if domain
        @ssl_cert_path = ssl_cert if ssl_cert
        @ssl_key_path  = ssl_key  if ssl_key
      end

      # Base WEBrick options; +_apply_webrick_ssl!+ folds in TLS when configured.
      # Distinct name from AgentBase#webrick_opts to avoid inheritance shadowing.
      def service_webrick_opts(bind_host, bind_port)
        opts = {
          Host: bind_host,
          Port: bind_port,
          Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
          AccessLog: []
        }
        _apply_webrick_ssl!(opts)
        opts
      end

      # Rack 3+ moved Handler to the rackup gem; fall back to the legacy
      # location on older Rack. Distinct name from AgentBase#webrick_handler.
      def service_webrick_handler
        require 'rackup/handler/webrick'
        Rackup::Handler::WEBrick
      rescue LoadError
        require 'rack/handler/webrick'
        Rack::Handler::WEBrick
      end

      # Classify where the active basic-auth pair came from, for the
      # 3-tuple form of #get_basic_auth_credentials. Distinct name from
      # AgentBase#basic_auth_source so neither shadows the other via inheritance.
      def service_basic_auth_source(user, pass)
        if service_auth_from_env?(user, pass)
          'environment'
        elsif user&.start_with?('user_') && pass && pass.length > 20
          'auto-generated'
        else
          'provided'
        end
      end

      def service_auth_from_env?(user, pass)
        env_user = ENV.fetch('SWML_BASIC_AUTH_USER', nil)
        env_pass = ENV.fetch('SWML_BASIC_AUTH_PASSWORD', nil)
        env_user && !env_user.empty? && env_pass && !env_pass.empty? && user == env_user && pass == env_pass
      end

      # The +sleep+ verb is special: it accepts a bare Integer (sleep(2000))
      # or a duration kwarg (sleep(duration: 2000)).
      def sleep_duration(args, kwargs)
        if args.length == 1 && args.first.is_a?(Integer)
          args.first
        elsif kwargs.key?(:duration)
          kwargs[:duration]
        elsif !kwargs.empty?
          kwargs.values.first
        else
          raise ArgumentError, 'sleep requires an integer duration'
        end
      end

      # Document, routing-callback registry, server handle, and the SWAIG tool
      # registry (lifted from AgentBase so any Service can register/dispatch
      # SWAIG functions).
      def init_document_state
        @document = Document.new
        @routing_callbacks = {}
        @server = nil
        @tools = {}            # name => { definition + handler }
        @swaig_functions = {}  # name => raw hash (DataMap etc.)
      end

      # Parameters:
      # - ``schema_path`` — explicit path to the SWML schema file. When nil we
      #   fall back to the schema bundled with the gem via SWML::Schema.
      # - ``config_file`` — TOML/YAML configuration override file. Ruby v1
      #   stashes the path; the loader is wired by AgentBase only when needed.
      # - ``schema_validation`` — when true (default), out-bound SWML is
      #   validated against the schema. ``SWML_SKIP_SCHEMA_VALIDATION=1`` env
      #   var overrides to false.
      def init_schema_config(schema_path, config_file, schema_validation)
        @schema_path        = schema_path
        @config_file        = config_file
        @schema_validation  = schema_validation && ENV['SWML_SKIP_SCHEMA_VALIDATION'] != '1'
      end

      # Strip a trailing slash, collapsing the empty result back to "/".
      def normalize_route(route)
        normalized = route.chomp('/')
        normalized.empty? ? '/' : normalized
      end

      # Resolve basic-auth credentials: explicit arg wins, then env pair,
      # then an auto-generated UUID pair. Distinct name from
      # AgentBase#resolve_basic_auth (which returns a [pair, bool] tuple) so
      # this is not shadowed when Service#initialize runs via super on an agent.
      def resolve_service_basic_auth(basic_auth)
        if basic_auth
          basic_auth
        elsif ENV['SWML_BASIC_AUTH_USER'] && ENV['SWML_BASIC_AUTH_PASSWORD']
          [ENV['SWML_BASIC_AUTH_USER'], ENV['SWML_BASIC_AUTH_PASSWORD']]
        else
          [SecureRandom.uuid, SecureRandom.uuid]
        end
      end

      # The server can be told to serve HTTPS via three env vars, consumed by
      # +serve+ / +AgentBase#serve+ to bind WEBrick with SSLEnable. Explicit
      # serve(ssl_cert:, ssl_key:, ssl_enabled:) kwargs still override these at
      # call time.
      #   SWML_SSL_ENABLED   — "true"/"1"/"yes" (case-insensitive) → on
      #   SWML_SSL_CERT_PATH — PEM certificate path
      #   SWML_SSL_KEY_PATH  — PEM private-key path
      def init_ssl_config
        @ssl_enabled   = %w[true 1 yes].include?(ENV['SWML_SSL_ENABLED'].to_s.strip.downcase)
        @ssl_cert_path = ENV.fetch('SWML_SSL_CERT_PATH', nil)
        @ssl_key_path  = ENV.fetch('SWML_SSL_KEY_PATH', nil)
        @domain        = ENV.fetch('SWML_DOMAIN', nil)
      end

      # Mutate a WEBrick option hash in place to enable HTTPS when SSL is
      # configured (+@ssl_enabled+ with both a cert and key path present).
      # Loads the PEM cert + private key with the generic +OpenSSL::PKey.read+
      # so RSA and EC keys both work. A no-op when SSL is off or incomplete,
      # so plain-HTTP serving is untouched. Shared by +SWMLService#serve+ and
      # +AgentBase#serve+ so both code paths bind TLS identically. Returns true
      # when SSL was applied, false otherwise.
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
      # +on_request+ customization hook, then any registered routing
      # callback, then the default rendered document.
      #
      # +request_data+ is the parsed JSON body (or nil). Returns the
      # SWML hash to serialise as the response.
      def dispatch_request(request_data, callback_path, headers = {})
        override = on_request(request_data, callback_path)
        return override if override.is_a?(Hash) && !override.empty?

        if @routing_callbacks.key?(callback_path)
          invoke_routing_callback(@routing_callbacks[callback_path], request_data, headers)
        else
          @document.to_h
        end
      end

      def build_rack_app
        main_route = @route
        authenticated = build_authenticated_app

        Rack::Builder.new do
          # Public endpoints (no auth).
          map('/health') { run ->(_env) { Service._status_response('healthy') } }
          map('/ready')  { run ->(_env) { Service._status_response('ready') } }

          # Authenticated endpoints (security headers + timing-safe Basic-Auth).
          map(main_route) { run authenticated }
        end
      end

      # The main-route app: security headers + Basic-Auth in front of the
      # body-parsing dispatcher.
      def build_authenticated_app
        service = self
        Rack::Builder.new do
          use SecurityHeadersMiddleware
          use TimingSafeBasicAuth, service
          run ->(env) { service.__send__(:handle_main_route, env) }
        end
      end

      # The authenticated main-route handler: parses the body, then routes to
      # /swaig, an additional-route hook, or the default SWML dispatcher.
      def handle_main_route(env)
        request = Rack::Request.new(env)

        sub_path = env['PATH_INFO'] || '/'
        sub_path = '/' if sub_path.empty?

        request_data = parse_json_body(request)

        # /swaig — handled by Service itself (lifted from AgentBase).
        return handle_swaig_endpoint(request, request_data, env) if sub_path == '/swaig'

        # Subclass extension hook for /post_prompt, /debug_events, /mcp, etc.
        extra = handle_additional_route(sub_path, request_data, env)
        return extra if extra

        # Fallback: customization hook, routing-callback, then SWML doc.
        result = dispatch_request(request_data, sub_path, rack_headers(env))
        [200, { 'content-type' => 'application/json' }, [JSON.generate(result)]]
      end

      # Extract request headers from a Rack +env+ as a plain Hash of the
      # conventional header names (so routing callbacks receive the same
      # +(body, headers)+ shape the primitive +handle_request+ passes).
      def rack_headers(env)
        env.each_with_object({}) do |(k, v), acc|
          next unless k.is_a?(String) && k.start_with?('HTTP_')

          name = k.delete_prefix('HTTP_').split('_').map(&:capitalize).join('-')
          acc[name] = v
        end
      end

      # Parse a JSON request body for POST/PUT, returning nil on absence or
      # parse failure. Distinct name from AgentBase#parse_request_body (which
      # takes a different arity) to avoid inheritance shadowing.
      def parse_json_body(request)
        return nil unless request.post? || request.put?

        JSON.parse(request.body.read)
      rescue StandardError
        nil
      end

      # Internal: handle GET/POST /swaig.
      # GET — returns the rendered SWML doc via render_main_swml.
      # POST — parses {function, argument, call_id}, validates, runs the
      # swaig_pre_dispatch hook, dispatches via on_function_call.
      def handle_swaig_endpoint(request, request_data, env)
        return swaig_json(200, render_main_swml(request_data, request: request)) if request.get?

        func_name = request_data && request_data['function']
        err = swaig_validation_error(request_data, func_name)
        return err if err

        dispatch_swaig_call(func_name, request_data, env)
      end

      # Run swaig_pre_dispatch then on_function_call, returning the Rack triple.
      def dispatch_swaig_call(func_name, request_data, env)
        args = extract_swaig_args(request_data)
        target, short_circuit = swaig_pre_dispatch(request_data, func_name, env)
        return swaig_json(200, short_circuit) if short_circuit

        result = target.on_function_call(func_name, args, request_data)
        return swaig_json(404, 'error' => "Unknown function: #{func_name}") if result.nil?

        swaig_json(200, result)
      end

      # JSON Rack response triple with the standard content-type.
      def swaig_json(status, payload)
        [status, { 'content-type' => 'application/json' }, [JSON.generate(payload)]]
      end

      # Validate the POST /swaig body; returns a 400 Rack triple on failure,
      # or nil when the request is well-formed.
      def swaig_validation_error(request_data, func_name)
        return swaig_json(400, 'error' => 'Missing request body') unless request_data
        return swaig_json(400, 'error' => 'Missing function name') if func_name.nil? || func_name.empty?
        return nil if SWAIG_FN_NAME.match?(func_name)

        swaig_json(400, 'error' => "Invalid function name format: '#{func_name}'")
      end

      # Argument extraction: nested {argument:{parsed:[...]}} OR flat {arguments}.
      def extract_swaig_args(request_data)
        if request_data['argument'].is_a?(Hash)
          parsed = request_data['argument']['parsed']
          return parsed.first if parsed.is_a?(Array) && !parsed.empty?
        elsif request_data['arguments'].is_a?(Hash)
          return request_data['arguments']
        end
        {}
      end

      # ------------------------------------------------------------------
      # Middleware: security headers
      # ------------------------------------------------------------------
      class SecurityHeadersMiddleware
        HEADERS = {
          'x-content-type-options' => 'nosniff',
          'x-frame-options' => 'DENY',
          'cache-control' => 'no-store, no-cache, must-revalidate'
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
          return unauthorized unless auth.provided? && auth.basic?

          credentials_ok?(auth) ? @app.call(env) : unauthorized
        end

        private

        # Timing-safe comparison of provided credentials to prevent timing attacks.
        def credentials_ok?(auth)
          user, pass = @service.get_basic_auth_credentials
          input_user, input_pass = auth.credentials
          secure_compare(user, input_user) && secure_compare(pass, input_pass)
        end

        def unauthorized
          # Python parity: a JSON {"error":"Unauthorized"} body (not plain text).
          [
            401,
            {
              'content-type' => 'application/json',
              'www-authenticate' => 'Basic realm="SignalWire SWML Service"'
            },
            [JSON.generate('error' => 'Unauthorized')]
          ]
        end

        # Rack::Utils.secure_compare performs a constant-time byte comparison.
        def secure_compare(lhs, rhs)
          Rack::Utils.secure_compare(lhs.to_s, rhs.to_s)
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
