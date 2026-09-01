# frozen_string_literal: true

require 'json'
require 'socket'
require 'securerandom'
require 'websocket-client-simple'

require_relative 'constants'
require_relative 'relay_event'
require_relative 'device'
require_relative 'collect_config'
require_relative 'action'
require_relative 'call'
require_relative 'message'
require_relative '../error'

module SignalWire
  module Relay
    # Raised for RELAY JSON-RPC errors.
    class RelayError < SignalWire::Error
      attr_reader :code, :error_message

      def initialize(code, message)
        @code          = code
        @error_message = message
        super("RELAY error #{code}: #{message}")
      end
    end

    # RelayClient -- WebSocket + JSON-RPC 2.0 protocol + event dispatch.
    #
    # One instance = one persistent WebSocket connection to SignalWire RELAY.
    #
    # Implements the 4 correlation mechanisms:
    # 1. JSON-RPC id -> pending hash with ConditionVariable
    # 2. call_id -> Call routing
    # 3. control_id -> Action tracking per Call
    # 4. tag -> dial correlation
    class Client
      attr_reader :project_id, :protocol, :host, :max_active_calls

      # Caller-supplied connection config, readable back. The reference exposes
      # every one of these as a public attribute set from the same-named
      # constructor param (relay/client.py:171-175), so a Ruby caller that can
      # PASS `token:`/`jwt_token:`/`contexts:` must be able to read them; they
      # were behind `private` until now, which took the read-back capability away
      # from Ruby callers only. (`space` stays private — it is a back-compat
      # alias for `host:` with no reference counterpart.)
      attr_reader :token, :jwt_token, :contexts

      # Field maps for event -> object construction: kwarg => [event key, default].
      INBOUND_CALL_FIELDS = {
        call_id: ['call_id', ''], node_id: ['node_id', ''], project_id: ['project_id', ''],
        tag: ['tag', ''], direction: %w[direction inbound], device: ['device', {}],
        state: ['call_state', ''], segment_id: ['segment_id', '']
      }.freeze
      INBOUND_MESSAGE_FIELDS = {
        message_id: ['message_id', ''], context: ['context', ''],
        from_number: ['from_number', ''], to_number: ['to_number', ''],
        body: ['body', ''], media: ['media', []], segments: ['segments', 0],
        state: %w[message_state received], tags: ['tags', []]
      }.freeze
      # Event types whose handler takes the outer params hash.
      OUTER_PARAM_EVENT_HANDLERS = {
        EVENT_CALL_RECEIVE => :handle_inbound_call,
        EVENT_CALL_DIAL => :handle_dial_event,
        EVENT_MESSAGING_RECEIVE => :handle_inbound_message,
        EVENT_MESSAGING_STATE => :handle_message_state
      }.freeze

      # Construct a RelayClient. An earlier release accepted ``space:``
      # for the same purpose; both keyword names are honoured for
      # backwards compat. ``host`` is the canonical name and drives the
      # WebSocket endpoint.
      #
      # @param project [String, nil] project ID (env: SIGNALWIRE_PROJECT_ID)
      # @param token [String, nil] API token (env: SIGNALWIRE_API_TOKEN)
      # @param jwt_token [String, nil] JWT token alternative
      #   (env: SIGNALWIRE_JWT_TOKEN)
      # @param host [String, nil] RELAY host (env: SIGNALWIRE_SPACE).
      #   Either a bare space subdomain (``myspace``) or full hostname
      #   (``myspace.signalwire.com``).
      # @param contexts [Array<String>] context names to subscribe to
      # @param max_active_calls [Integer, nil] cap on simultaneous
      #   active inbound calls. ``nil`` means unlimited (overridable via
      #   the ``RELAY_MAX_ACTIVE_CALLS`` env var).
      # @param space [String, nil] backwards-compat alias for ``host``.
      def initialize(project: nil, token: nil, jwt_token: nil, host: nil,
                     contexts: ['default'], max_active_calls: nil,
                     space: nil)
        @jwt_token  = value_or_env(jwt_token, 'SIGNALWIRE_JWT_TOKEN')
        @contexts   = contexts
        @max_active_calls = resolve_max_active_calls(max_active_calls)
        resolve_credentials(project, token, host, space)

        validate_credentials
        @host = @space.include?('.') ? @space : "#{@space}.signalwire.com"

        init_correlation_state
        init_session_state
      end

      private

      # Back-compat-only connection config, set once during initialize.
      attr_reader :space

      def resolve_credentials(project, token, host, space)
        @project_id = value_or_env(project, 'SIGNALWIRE_PROJECT_ID')
        @token      = value_or_env(token, 'SIGNALWIRE_API_TOKEN')
        # Accept either `host:` (Python parity) or legacy `space:`.
        @space      = value_or_env(host || space, 'SIGNALWIRE_SPACE')
      end

      def value_or_env(explicit, env_key)
        explicit || ENV[env_key] || ''
      end

      # Resolve max_active_calls: the explicit arg, else the
      # RELAY_MAX_ACTIVE_CALLS env var.
      def resolve_max_active_calls(max_active_calls)
        if max_active_calls.nil?
          env_val = ENV.fetch('RELAY_MAX_ACTIVE_CALLS', nil)
          env_val && !env_val.empty? ? Integer(env_val) : nil
        else
          [1, Integer(max_active_calls)].max
        end
      end

      def validate_credentials
        # JWT auth (env: SIGNALWIRE_JWT_TOKEN or the jwt_token: kwarg) is a
        # self-contained alternative to project/token — the project id lives
        # inside the token, so only the host is still required. Mirrors the
        # Python reference's truthiness check (an empty jwt_token is no token).
        unless jwt_token.empty?
          raise ArgumentError, 'host is required (set SIGNALWIRE_SPACE)' if space.empty?

          return
        end
        # Per-variable actionable pre-connect errors (A6): each names the missing
        # credential AND its env var so a failure is self-diagnosing. Mirrors the
        # python reference (client.py project-is-required / token-is-required).
        raise ArgumentError, 'project is required (set SIGNALWIRE_PROJECT_ID)' if project_id.empty?
        raise ArgumentError, 'token or jwt_token is required (set SIGNALWIRE_API_TOKEN)' if token.empty?
        raise ArgumentError, 'host is required (set SIGNALWIRE_SPACE)' if space.empty?
      end

      def init_correlation_state
        # Correlation mechanisms
        @pending       = {} # id -> { mutex:, cv:, result:, error: }
        @pending_mutex = Mutex.new
        @calls         = {} # call_id -> Call
        @calls_mutex   = Mutex.new
        @pending_dials = {} # tag -> { mutex:, cv:, call:, error: }
        @dials_mutex   = Mutex.new
        @messages      = {} # message_id -> Message
        @messages_mutex = Mutex.new
      end

      def init_session_state
        # Session state
        @protocol            = nil
        @authorization_state = nil
        # Server-assigned session id from the connect handshake. Kept off the
        # public surface (single-underscore reader, like +_set_protocol+ and
        # +_authorization_state+, so the surface oracle excludes it) and never
        # widens the developer-facing API. Test-harness support only: the
        # mock-relay tests read it (via +_session_id+) to scope the shared
        # mock's journal to their own connection. This mirrors the frozen
        # TypeScript port's private +_sessionId+ capture; Python's RelayClient
        # doesn't surface it either, so no public-surface parity is affected.
        @session_id          = nil
        @ws                  = nil
        @running             = false
        @connected           = false
        @ws_mutex            = Mutex.new

        # Reconnection backoff
        @reconnect_delay = RECONNECT_MIN_DELAY
        @should_restart  = false
        init_handlers
      end

      def init_handlers
        @on_call_handler    = nil
        @on_message_handler = nil
        @on_event_handler   = nil
      end

      public

      # Redacted inspect: NEVER print the raw API token, JWT, or the server's
      # authorization_state re-auth blob — the default #inspect dumps every ivar,
      # leaking every credential into logs / crash dumps / a REPL session.
      # Enterprise credential-hygiene (A6 / SECRET-SCRUB): show only the
      # non-secret identity + connection state.
      def inspect
        "#<#{self.class.name} project_id=#{@project_id.inspect} " \
          "host=#{@host.inspect} connected=#{@connected} " \
          'token=[REDACTED] jwt_token=[REDACTED] authorization_state=[REDACTED]>'
      end
      alias to_s inspect

      # Register inbound call handler.
      def on_call(&block)
        @on_call_handler = block
      end

      # Register inbound message handler.
      def on_message(&block)
        @on_message_handler = block
      end

      # Register a generic inbound-event handler. Called for every
      # +signalwire.event+ frame BEFORE the type-specific handlers
      # (call/message/dial) run. Used by integration probes (e.g. the
      # audit harness) that need to react to raw events.
      def on_event(&block)
        @on_event_handler = block
      end

      # Send an arbitrary JSON-RPC frame to the server. Public surface for
      # tests, the audit harness, and one-off RELAY methods that don't
      # have a high-level wrapper. Returns nothing; outbound failures are
      # silently ignored (matching +_send_json+ semantics).
      def send_json(msg)
        _send_json(msg)
      end

      # Return the current call_id -> Call registry (a snapshot copy).
      # Test/audit-only surface for asserting on internal routing state;
      # the Python reference exposes the same via +RelayClient._calls+.
      def _calls_snapshot
        @calls_mutex.synchronize { @calls.dup }
      end

      # Test/reconnect surface: stamp a previously issued protocol
      # string before calling +run+ so the next signalwire.connect frame
      # carries it (the production server replies with
      # +session_restored: true+). Mirrors Python's +RelayClient._relay_protocol = ...+.
      def _set_protocol(value)
        @protocol = value
      end

      # Return the SDK's tracked authorization-state blob. Captured from
      # +signalwire.authorization.state+ events for use on reconnect.
      def _authorization_state
        @authorization_state
      end

      # Return the server-assigned session id captured from the connect
      # handshake. Internal/test surface only (single-underscore => not part
      # of the public API, like +_set_protocol+): the test harness reads it
      # to scope its journal/scenario calls to this connection so the shared
      # mock is safe under parallel test execution. +nil+ until
      # +run+/+connect+ completes the handshake.
      def _session_id
        @session_id
      end

      # True when the client believes the WebSocket is open. Exposed for
      # tests that need to assert the recv loop is still alive after an
      # injected error / handler exception.
      def _connected?
        @ws_mutex.synchronize { @connected }
      end

      # Connect, authenticate, subscribe, and enter the read loop.
      # Blocks until stop is called.
      def run
        @running = true
        while @running
          connect_and_run_guarded
          break unless @running

          reject_all_pending('Disconnected')
          backoff_reconnect
        end
      end

      # Establish the RELAY connection without entering the blocking reconnect
      # loop. Mirrors Python RelayClient.connect — brings the socket up and
      # returns; use run() for the blocking, auto-reconnecting event loop and
      # disconnect()/stop() to tear down.
      def connect
        @running = true
        connect_and_run_guarded
        self
      end

      # Graceful shutdown. Also exposed as +disconnect+ (Python name) via the
      # surface enumerator alias.
      def stop
        @running = false
        # Snapshot under the mutex, close outside it. The websocket-client
        # gem fires the `:close` callback synchronously inside `close`,
        # which re-enters on_ws_close → tries to take @ws_mutex and
        # deadlocks if we're still holding it.
        ws_to_close = nil
        @ws_mutex.synchronize do
          ws_to_close = @ws if @connected
        end
        ws_to_close&.close
        reject_all_pending('Client stopped')
      end

      # ------------------------------------------------------------------
      # Outbound dial
      # ------------------------------------------------------------------

      # Dial outbound call(s). Returns a Call object.
      def dial(devices, timeout: 120, tag: nil, **kwargs)
        dial_tag = tag || SecureRandom.uuid

        # Register pending dial BEFORE sending RPC
        entry = { mutex: Mutex.new, cv: ConditionVariable.new, call: nil, error: nil }
        @dials_mutex.synchronize { @pending_dials[dial_tag] = entry }

        send_dial_rpc(dial_tag, devices, kwargs)
        await_dial(dial_tag, entry, timeout)
        @dials_mutex.synchronize { @pending_dials.delete(dial_tag) }
        raise RelayError.new(-1, entry[:error]) if entry[:error]

        entry[:call]
      end

      # ------------------------------------------------------------------
      # Outbound message
      # ------------------------------------------------------------------

      # Send an SMS/MMS message. Returns a Message object.
      #
      # Mirrors Python's RelayClient.send_message keyword-only signature
      # exactly. At least one of body: or media: is required.
      def send_message(to_number:, from_number:, context: nil, body: nil,
                       media: nil, tags: nil, region: nil, on_completed: nil)
        validate_message_payload(body, media)
        msg_context = context || contexts.first || 'default'
        params = build_message_params(msg_context, to_number, from_number, body: body, media: media,
                                                                           tags: tags, region: region)
        message_id = execute('messaging.send', params)['message_id'] || ''

        msg = build_outbound_message(message_id, msg_context, to_number, from_number,
                                     body: body, media: media, tags: tags)
        msg._set_on_completed(on_completed) if on_completed
        @messages_mutex.synchronize { @messages[message_id] = msg } unless message_id.empty?
        msg
      end

      # ------------------------------------------------------------------
      # Dynamic context subscription
      # ------------------------------------------------------------------

      def receive(contexts)
        execute('signalwire.receive', { 'contexts' => contexts })
      end

      def unreceive(contexts)
        execute('signalwire.unreceive', { 'contexts' => contexts })
      end

      # ------------------------------------------------------------------
      # JSON-RPC execute
      # ------------------------------------------------------------------

      # Send a JSON-RPC request and wait for the response.
      # Returns the result hash. Raises RelayError on error.
      def execute(method, params = {})
        id = SecureRandom.uuid
        entry = { mutex: Mutex.new, cv: ConditionVariable.new, result: nil, error: nil }
        @pending_mutex.synchronize { @pending[id] = entry }

        # Python parity: params are sent VERBATIM. The protocol is only carried
        # on the signalwire.connect handshake (see apply_session_restore), NOT
        # injected into every calling.*/messaging.* frame.
        _send_json('jsonrpc' => '2.0', 'id' => id, 'method' => method,
                   'params' => params)
        await_response(id, entry, method)

        @pending_mutex.synchronize { @pending.delete(id) }
        raise entry[:error] if entry[:error]

        check_result_code(method, entry[:result])
        entry[:result]
      end

      private

      def connect_and_run_guarded
        connect_and_run
      rescue StandardError => e
        warn "[RELAY] Connection error: #{e.message}"
      end

      # Exponential backoff between reconnect attempts.
      def backoff_reconnect
        warn "[RELAY] Reconnecting in #{@reconnect_delay}s..."
        sleep(@reconnect_delay)
        @reconnect_delay = [@reconnect_delay * RECONNECT_BACKOFF_FACTOR, RECONNECT_MAX_DELAY].min
      end

      # Wait for the calling.call.dial event (or error/timeout) for a dial.
      def await_dial(dial_tag, entry, timeout)
        wait_on_entry(entry, timeout, -> { entry[:call].nil? && entry[:error].nil? }) do
          @dials_mutex.synchronize { @pending_dials.delete(dial_tag) }
          raise ActionTimeoutError, "Dial timed out after #{timeout}s"
        end
      end

      # Block on entry[:cv] under entry[:mutex] until +pending+ returns false or
      # the timeout elapses; on timeout, run the +on_timeout+ block.
      def wait_on_entry(entry, timeout, pending)
        entry[:mutex].synchronize do
          deadline = Time.now + timeout
          while pending.call
            remaining = deadline - Time.now
            yield if remaining <= 0
            entry[:cv].wait(entry[:mutex], remaining)
          end
        end
      end

      def validate_message_payload(body, media)
        return unless (body.nil? || body.empty?) && (media.nil? || media.empty?)

        raise ArgumentError, 'body or media is required'
      end

      def send_dial_rpc(dial_tag, devices, kwargs)
        params = { 'tag' => dial_tag, 'devices' => devices }
        kwargs.each { |k, v| params[k.to_s] = v }
        execute('calling.dial', params)
      rescue StandardError
        @dials_mutex.synchronize { @pending_dials.delete(dial_tag) }
        raise
      end

      def build_message_params(msg_context, to_number, from_number, body:, media:, tags:, region:)
        params = { 'context' => msg_context, 'to_number' => to_number, 'from_number' => from_number }
        params['body']   = body   if body
        params['media']  = media  if media
        params['tags']   = tags   if tags
        params['region'] = region if region
        params
      end

      def build_outbound_message(message_id, msg_context, to_number, from_number, body:, media:, tags:)
        Message.new(
          message_id: message_id, context: msg_context, direction: 'outbound',
          from_number: from_number, to_number: to_number,
          body: body || '', media: media || [], state: 'queued', tags: tags || []
        )
      end

      # Wait for a JSON-RPC response (10s timeout to detect half-open connections).
      def await_response(id, entry, method)
        wait_on_entry(entry, 10, -> { entry[:result].nil? && entry[:error].nil? }) do
          @pending_mutex.synchronize { @pending.delete(id) }
          raise RelayError.new(-1, "Request #{method} timed out")
        end
      end

      def check_result_code(method, result)
        return if method == METHOD_SIGNALWIRE_CONNECT

        code = result['code']
        raise RelayError.new(code, result['message'] || 'Unknown error') if code && !code.to_s.match?(/\A2\d\d\z/)
      end

      # ------------------------------------------------------------------
      # WebSocket connection lifecycle
      # ------------------------------------------------------------------

      def connect_and_run
        scheme = relay_scheme
        url = "#{scheme}://#{relay_endpoint_host}"
        # Secure-by-default WSS verification options (empty for plain ws://).
        open_websocket(url, wss_tls_options(scheme))

        @ws_mutex.synchronize { @connected = true }
        @reconnect_delay = RECONNECT_MIN_DELAY
        authenticate

        # Keep reading until disconnected. The websocket-client-simple gem does
        # NOT surface a peer close on its read thread (on EOF its getc returns
        # nil and it just sleeps+retries, never emitting :close), so a
        # post-auth TCP drop would otherwise leave @connected stuck true and the
        # reconnect loop would never run. Poll for a peer close and force the
        # teardown that triggers reconnect (F3 liveness).
        sleep(1) while @running && @connected && !peer_closed?
        @ws_mutex.synchronize { @connected = false } if @running
      end

      # True when the underlying transport socket has seen a peer close (TCP FIN
      # / EOF). Uses a NON-consuming MSG_PEEK so it never steals a byte from the
      # gem's read thread: a readable socket that peeks empty is at EOF (closed);
      # a readable socket with bytes pending is a live frame the gem will read.
      def peer_closed?
        raw = raw_transport_socket
        return true if raw.nil? || raw.closed?
        return false unless raw.wait_readable(0)

        # A readable socket that peeks nil/empty is at EOF (peer closed); bytes
        # pending mean a live frame the gem will read (PEEK never consumes them).
        peeked = raw.recv_nonblock(1, Socket::MSG_PEEK)
        peeked.nil? || peeked.empty?
      rescue IO::WaitReadable
        false
      rescue Errno::ECONNRESET, Errno::ENOTCONN, IOError
        # IOError covers EOFError; a reset/not-connected peer is closed.
        true
      end

      # The plain transport socket under the websocket-client-simple client (a
      # TCPSocket for ws://; an SSLSocket for wss:// — its #to_io is the TCP
      # socket). nil when unavailable.
      def raw_transport_socket
        sock = @ws&.instance_variable_get(:@socket)
        return nil if sock.nil?

        sock.respond_to?(:to_io) ? sock.to_io : sock
      rescue StandardError
        nil
      end

      # Open the WebSocket and block until it reports open, raising on error.
      def open_websocket(url, ws_options)
        # Shared open/error signalling between the connect callbacks and here.
        ready = { mutex: Mutex.new, cv: ConditionVariable.new, flag: false, error: nil }
        @ws = WebSocket::Client::Simple.connect(url, ws_options) { |ws| wire_ws_callbacks(ws, ready) }
        ready[:mutex].synchronize { ready[:cv].wait(ready[:mutex], 15) until ready[:flag] }
        raise ready[:error] if ready[:error]
      end

      # In production we connect to wss://{space}. The audit fixture binds an
      # ephemeral port on 127.0.0.1 and serves plain ws://; SIGNALWIRE_RELAY_HOST
      # and SIGNALWIRE_RELAY_SCHEME let the audit harness redirect the client
      # there without touching production credential resolution.
      def relay_scheme
        scheme = ENV.fetch('SIGNALWIRE_RELAY_SCHEME', nil)
        scheme.nil? || scheme.empty? ? 'wss' : scheme
      end

      def relay_endpoint_host
        host_override = ENV.fetch('SIGNALWIRE_RELAY_HOST', nil)
        host_override.nil? || host_override.empty? ? host : host_override
      end

      # Wire the open/message/error/close callbacks onto the websocket. +ready+
      # is the shared signalling hash (see connect_and_run).
      def wire_ws_callbacks(socket, ready)
        client_ref = self
        socket.on(:message) { |msg| client_ref.send(:on_ws_message, msg.data) }
        socket.on(:open)  { client_ref.send(:on_ws_lifecycle, :on_ws_open, ready) }
        socket.on(:close) { client_ref.send(:on_ws_lifecycle, :on_ws_close, ready) }
        socket.on(:error) do |err|
          ready[:error] = err
          client_ref.send(:signal_ready, ready)
        end
      end

      def on_ws_lifecycle(hook, ready)
        send(hook)
        signal_ready(ready)
      end

      def signal_ready(ready)
        ready[:mutex].synchronize do
          ready[:flag] = true
          ready[:cv].signal
        end
      end

      # Build the TLS options hash for WebSocket::Client::Simple.connect.
      #
      # For a wss:// endpoint this returns +{ verify_mode:, cert_store: }+ that
      # enforce real certificate verification (VERIFY_PEER) against a store
      # seeded from the OpenSSL default paths (which honor the SSL_CERT_FILE /
      # SSL_CERT_DIR env vars) plus, when set, the explicit CA bundle named by
      # the fleet-standard SIGNALWIRE_RELAY_CA_FILE. For any non-wss scheme (plain ws:// used
      # by the loopback audit fixtures) it returns an empty hash so the
      # transport stays untouched.
      #
      # @param scheme [String] the URL scheme ("wss" or "ws")
      # @return [Hash] connect options ({} for plain ws://)
      # @api private
      def wss_tls_options(scheme)
        return {} unless scheme == 'wss'

        require 'openssl'
        store = OpenSSL::X509::Store.new
        store.set_default_paths
        ca_file = ENV.fetch('SIGNALWIRE_RELAY_CA_FILE', nil)
        store.add_file(ca_file) if ca_file && !ca_file.empty? && File.file?(ca_file)

        { verify_mode: OpenSSL::SSL::VERIFY_PEER, cert_store: store }
      end

      def on_ws_open
        # Connection opened
      end

      def on_ws_message(data)
        return if data.nil? || data.empty?

        begin
          msg = JSON.parse(data)
        rescue JSON::ParserError => e
          warn "[RELAY] Failed to parse message: #{e.message}"
          return
        end

        handle_message(msg)
      end

      def on_ws_close
        @ws_mutex.synchronize { @connected = false }
      end

      def _send_json(msg)
        @ws_mutex.synchronize do
          return unless @ws && @connected

          @ws.send(JSON.generate(msg))
        end
      end

      # ------------------------------------------------------------------
      # Authentication
      # ------------------------------------------------------------------

      def authenticate
        params = { 'version' => PROTOCOL_VERSION, 'agent' => AGENT_STRING, 'event_acks' => true }
        apply_auth_credentials(params)
        params['contexts'] = contexts unless contexts.empty?
        apply_session_restore(params)
        clear_restart_state if @should_restart

        result = execute(METHOD_SIGNALWIRE_CONNECT, params)
        @protocol = result['protocol'] if result['protocol']
        # Capture the server-assigned session id from the ConnectResult. Stays
        # internal (test-harness only, via +_session_id+) to scope the shared
        # mock relay's journal to this connection for parallel-safe tests;
        # mirrors the frozen TypeScript port's +_sessionId+ capture.
        @session_id = result['sessionid'] if result['sessionid']
      end

      def apply_session_restore(params)
        return if @should_restart

        params['protocol'] = @protocol if @protocol
        params['authorization_state'] = @authorization_state if @authorization_state
      end

      def apply_auth_credentials(params)
        # An unset jwt_token is the empty string (env fallback), not nil — and
        # in Ruby '' is truthy, so guard on emptiness to match Python's
        # truthiness check (`if self.jwt_token:`).
        unless jwt_token.empty?
          params['authentication'] = { 'jwt_token' => jwt_token }
          return
        end

        params['authentication'] = { 'project' => project_id, 'token' => token }
        # Audit fixtures and Blade-aware servers also accept the credentials at
        # the top level. Python's RELAY emits them in `authentication`; the audit
        # harness watches the top level. Emit both to satisfy both consumers.
        params['project'] = project_id
        params['token']   = token
      end

      def clear_restart_state
        @protocol = nil
        @authorization_state = nil
        @should_restart = false
      end

      # ------------------------------------------------------------------
      # Message dispatch
      # ------------------------------------------------------------------

      def handle_message(msg)
        # A frame with no method is a response to a pending request.
        return handle_response(msg) if msg['method'].nil?

        dispatch_method(msg)
      end

      def dispatch_method(msg)
        id = msg['id']
        case msg['method']
        when METHOD_SIGNALWIRE_EVENT      then _handle_event(msg)
        when METHOD_SIGNALWIRE_PING       then _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} })
        when METHOD_SIGNALWIRE_DISCONNECT then handle_disconnect(msg)
        else
          # Unknown method, send empty result
          _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} }) if id
        end
      end

      def handle_response(msg)
        id = msg['id']
        return unless id

        entry = @pending_mutex.synchronize { @pending[id] }
        return unless entry

        if msg['error']
          err = msg['error']
          settle_pending(entry, error: RelayError.new(err['code'], err['message'] || 'Unknown error'))
        else
          settle_pending(entry, result: msg['result'] || {})
        end
      end

      def settle_pending(entry, result: nil, error: nil, call: nil)
        entry[:mutex].synchronize do
          entry[:result] = result unless result.nil?
          entry[:error]  = error unless error.nil?
          entry[:call]   = call unless call.nil?
          entry[:cv].signal
        end
      end

      def _handle_event(msg)
        id = msg['id']
        outer_params = msg['params'] || {}
        _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} }) if id # ACK immediately

        event_type   = outer_params['event_type'] || ''
        event_params = outer_params['params'] || {}
        call_id      = event_params['call_id'] || ''

        invoke_event_hook(event_type, event_params, outer_params)
        return if dispatch_typed_event(event_type, event_params, outer_params, call_id)

        route_event_to_call(call_id, outer_params)
      end

      # Generic event hook (audit harnesses, integration tests). Runs BEFORE
      # type-specific dispatch so a probe can observe every event the SDK saw.
      def invoke_event_hook(event_type, event_params, outer_params)
        return unless @on_event_handler

        @on_event_handler.call(event_type, event_params, outer_params)
      rescue StandardError => e
        warn "[RELAY] Error in on_event handler: #{e.message}"
      end

      # Handle the type-specific events that terminate dispatch. Returns true
      # when the event was fully handled (caller should stop), false otherwise.
      # EVENT_CALL_STATE pre-registers a dial leg then returns false so the
      # caller falls through to normal call routing.
      def dispatch_typed_event(event_type, event_params, outer_params, call_id)
        case event_type
        when EVENT_AUTHORIZATION_STATE
          @authorization_state = event_params['authorization_state']
          true
        when EVENT_CALL_STATE
          maybe_register_dial_leg(event_params, call_id)
          false
        else
          dispatch_outer_param_event(event_type, outer_params)
        end
      end

      def dispatch_outer_param_event(event_type, outer_params)
        handler = OUTER_PARAM_EVENT_HANDLERS[event_type]
        return false unless handler

        send(handler, outer_params)
        true
      end

      def maybe_register_dial_leg(event_params, call_id)
        tag = event_params['tag'] || ''
        return if tag.empty?
        return unless @dials_mutex.synchronize { @pending_dials.key?(tag) }

        has_call = @calls_mutex.synchronize { @calls.key?(call_id) }
        register_dial_leg(tag, event_params) unless has_call || call_id.empty?
      end

      # Normal routing by call_id.
      def route_event_to_call(call_id, outer_params)
        return if call_id.empty?

        call = @calls_mutex.synchronize { @calls[call_id] }
        return unless call

        call._dispatch_event(outer_params)
        return unless call.state == CALL_STATE_ENDED

        @calls_mutex.synchronize { @calls.delete(call_id) }
      end

      def handle_disconnect(msg)
        id = msg['id']
        params = msg['params'] || {}

        # Respond with empty result
        _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} }) if id

        # Check restart flag
        @should_restart = params['restart'] == true

        # Let the connection close, reconnect will happen automatically
        @ws_mutex.synchronize { @connected = false }
      end

      def handle_inbound_call(payload)
        event_params = payload['params'] || {}
        # Dedup FIRST (short-circuit): a redelivery for a call already in the
        # map is not a new call, so it must never be counted against the cap.
        return if redelivered_receive?(event_params['call_id']) || max_active_calls_reached?

        call = build_inbound_call(event_params)
        @calls_mutex.synchronize { @calls[call.call_id] = call }

        return unless @on_call_handler

        Thread.new do
          @on_call_handler.call(call)
        rescue StandardError => e
          warn "[RELAY] Error in on_call handler: #{e.message}"
        end
      end

      # True when +call_id+ is already tracked, i.e. RELAY redelivered a
      # calling.call.receive for a call already in flight (it delivers at least
      # once). Receive is idempotent per call_id: the live instance is kept and
      # the on_call handler is NOT re-entered. Replacing the map entry would
      # orphan the Call the application is holding -- routing only ever reads
      # @calls by call_id, so the original would silently stop receiving events
      # and a blocking action on it would wait out its timeout instead of
      # returning at hangup. The event is ACKed by the recv loop before this
      # runs, so returning early still stops the server's retries.
      def redelivered_receive?(call_id)
        return false if call_id.nil?

        in_flight = @calls_mutex.synchronize { @calls.key?(call_id) }
        warn "[RELAY] Ignoring redelivered calling.call.receive for in-flight call #{call_id}" if in_flight
        in_flight
      end

      # True when the configured max_active_calls cap is reached, so the N+1th
      # inbound call is DROPPED (not silently accepted). nil cap = unlimited.
      # Mirrors python client.py _handle_inbound_call (len(_calls) >= cap).
      def max_active_calls_reached?
        cap = @max_active_calls
        return false if cap.nil?

        reached = @calls_mutex.synchronize { @calls.size >= cap }
        warn "[RELAY] Max active calls (#{cap}) reached, dropping inbound call" if reached
        reached
      end

      def build_inbound_call(event_params)
        kwargs = extract_fields(event_params, INBOUND_CALL_FIELDS)
        kwargs[:context] = event_params['context'] || event_params['protocol'] || ''
        Call.new(self, **kwargs)
      end

      # Pull mapped keys out of +params+, applying defaults. Centralizes the
      # nil-coalescing so the per-builder methods stay simple.
      def extract_fields(params, field_map)
        field_map.transform_values { |key, default| params[key] || default }
      end

      def handle_dial_event(payload)
        event_params = payload['params'] || {}
        tag = event_params['tag'] || ''
        entry = @dials_mutex.synchronize { @pending_dials[tag] }
        return unless entry

        case event_params['dial_state']
        when 'answered' then dial_answered(entry, tag, event_params['call'] || {})
        when 'failed'   then settle_pending(entry, error: 'Dial failed')
        end
      end

      def dial_answered(entry, tag, call_info)
        call_id = call_info['call_id'] || ''
        call = @calls_mutex.synchronize { @calls[call_id] }
        unless call
          call = build_dialed_call(call_id, tag, call_info)
          @calls_mutex.synchronize { @calls[call_id] = call }
        end
        call.state = CALL_STATE_ANSWERED
        settle_pending(entry, call: call)
      end

      def build_dialed_call(call_id, tag, call_info)
        Call.new(
          self,
          call_id: call_id,
          node_id: call_info['node_id'] || '',
          project_id: project_id,
          tag: call_info['tag'] || tag,
          direction: 'outbound',
          device: call_info['device'] || {},
          state: CALL_STATE_ANSWERED
        )
      end

      def register_dial_leg(tag, event_params)
        call_id = event_params['call_id'] || ''
        return if call_id.empty?

        call = Call.new(
          self, call_id: call_id, project_id: project_id, tag: tag, direction: 'outbound',
                node_id: event_params['node_id'] || '', device: event_params['device'] || {},
                state: event_params['call_state'] || ''
        )
        @calls_mutex.synchronize { @calls[call_id] = call }
      end

      def handle_inbound_message(payload)
        msg = build_inbound_message(payload['params'] || {})

        return unless @on_message_handler

        Thread.new do
          @on_message_handler.call(msg)
        rescue StandardError => e
          warn "[RELAY] Error in on_message handler: #{e.message}"
        end
      end

      def build_inbound_message(event_params)
        Message.new(direction: 'inbound', **extract_fields(event_params, INBOUND_MESSAGE_FIELDS))
      end

      def handle_message_state(payload)
        event_params = payload['params'] || {}
        message_id = event_params['message_id'] || ''

        msg = @messages_mutex.synchronize { @messages[message_id] }
        return unless msg

        msg._dispatch_event(payload)

        # Clean up terminal messages
        return unless msg.done?

        @messages_mutex.synchronize { @messages.delete(message_id) }
      end

      def reject_all_pending(reason)
        @pending_mutex.synchronize do
          @pending.each_value { |entry| reject_entry(entry, RelayError.new(-1, reason)) }
          @pending.clear
        end

        @dials_mutex.synchronize do
          @pending_dials.each_value { |entry| reject_entry(entry, reason) }
          @pending_dials.clear
        end
      end

      def reject_entry(entry, error)
        entry[:mutex].synchronize do
          entry[:error] ||= error
          entry[:cv].signal
        end
      end

      # Internal helpers (formerly leading-underscore by convention). Not part
      # of the public/Python surface -- declared private so the cross-port
      # surface enumerator continues to exclude them. _send_json / _connected? /
      # _calls_snapshot / _set_protocol / _authorization_state / _session_id stay
      # public+underscored (invoked cross-instance by tests / the send_json wrapper).
      private :apply_auth_credentials, :apply_session_restore, :authenticate, :await_dial,
              :await_response, :backoff_reconnect, :build_dialed_call, :build_inbound_call,
              :build_inbound_message, :build_message_params, :build_outbound_message, :check_result_code,
              :clear_restart_state, :connect_and_run, :connect_and_run_guarded, :dial_answered,
              :dispatch_method, :dispatch_outer_param_event, :dispatch_typed_event, :extract_fields,
              :handle_dial_event, :handle_disconnect, :handle_inbound_call,
              :handle_inbound_message, :handle_message, :handle_message_state, :handle_response,
              :init_correlation_state, :init_handlers, :init_session_state, :invoke_event_hook,
              :maybe_register_dial_leg, :on_ws_close, :on_ws_lifecycle, :on_ws_message,
              :on_ws_open, :open_websocket, :register_dial_leg, :reject_all_pending,
              :reject_entry, :relay_endpoint_host, :relay_scheme, :resolve_credentials,
              :resolve_max_active_calls, :route_event_to_call, :send_dial_rpc, :settle_pending,
              :signal_ready, :validate_credentials, :validate_message_payload, :value_or_env,
              :wait_on_entry, :wire_ws_callbacks, :wss_tls_options
    end
  end
end
