# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'websocket-client-simple'

module SignalWire
  module Relay
    # Raised for RELAY JSON-RPC errors.
    class RelayError < StandardError
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
      attr_reader :project_id, :protocol

      def initialize(project: nil, token: nil, jwt_token: nil, space: nil,
                     contexts: ['default'])
        @project_id = project || ENV['SIGNALWIRE_PROJECT_ID'] || ''
        @token      = token || ENV['SIGNALWIRE_API_TOKEN'] || ''
        @jwt_token  = jwt_token
        @space      = space || ENV['SIGNALWIRE_SPACE'] || ''
        @contexts   = contexts

        raise ArgumentError, 'project is required' if @project_id.empty?
        if @token.empty? && @jwt_token.nil?
          raise ArgumentError, 'token or jwt_token is required'
        end
        raise ArgumentError, 'space is required' if @space.empty?

        @host = @space.include?('.') ? @space : "#{@space}.signalwire.com"

        # Correlation mechanisms
        @pending       = {} # id -> { mutex:, cv:, result:, error: }
        @pending_mutex = Mutex.new
        @calls         = {} # call_id -> Call
        @calls_mutex   = Mutex.new
        @pending_dials = {} # tag -> { mutex:, cv:, call:, error: }
        @dials_mutex   = Mutex.new
        @messages      = {} # message_id -> Message
        @messages_mutex = Mutex.new

        # Session state
        @protocol            = nil
        @authorization_state = nil
        @ws                  = nil
        @running             = false
        @connected           = false
        @ws_mutex            = Mutex.new

        # Handlers
        @on_call_handler    = nil
        @on_message_handler = nil

        # Reconnection
        @reconnect_delay = RECONNECT_MIN_DELAY
        @should_restart  = false
      end

      # Register inbound call handler.
      def on_call(&block)
        @on_call_handler = block
      end

      # Register inbound message handler.
      def on_message(&block)
        @on_message_handler = block
      end

      # Connect, authenticate, subscribe, and enter the read loop.
      # Blocks until stop is called.
      def run
        @running = true
        while @running
          begin
            _connect_and_run
          rescue => e
            $stderr.puts "[RELAY] Connection error: #{e.message}"
          end
          break unless @running

          # Reject all pending requests
          _reject_all_pending('Disconnected')

          # Exponential backoff reconnect
          $stderr.puts "[RELAY] Reconnecting in #{@reconnect_delay}s..."
          sleep(@reconnect_delay)
          @reconnect_delay = [
            @reconnect_delay * RECONNECT_BACKOFF_FACTOR,
            RECONNECT_MAX_DELAY
          ].min
        end
      end

      # Graceful shutdown.
      def stop
        @running = false
        @ws_mutex.synchronize do
          @ws&.close if @connected
        end
        _reject_all_pending('Client stopped')
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

        begin
          params = { 'tag' => dial_tag, 'devices' => devices }
          kwargs.each { |k, v| params[k.to_s] = v }
          execute('calling.dial', params)
        rescue => e
          @dials_mutex.synchronize { @pending_dials.delete(dial_tag) }
          raise
        end

        # Wait for calling.call.dial event
        entry[:mutex].synchronize do
          deadline = Time.now + timeout
          while entry[:call].nil? && entry[:error].nil?
            remaining = deadline - Time.now
            if remaining <= 0
              @dials_mutex.synchronize { @pending_dials.delete(dial_tag) }
              raise ActionTimeoutError, "Dial timed out after #{timeout}s"
            end
            entry[:cv].wait(entry[:mutex], remaining)
          end
        end

        @dials_mutex.synchronize { @pending_dials.delete(dial_tag) }
        raise RelayError.new(-1, entry[:error]) if entry[:error]
        entry[:call]
      end

      # ------------------------------------------------------------------
      # Outbound message
      # ------------------------------------------------------------------

      # Send an SMS/MMS message. Returns a Message object.
      def send_message(to:, from:, body: nil, media: nil, context: nil,
                       tags: nil, on_completed: nil, **kwargs)
        raise ArgumentError, 'body or media is required' if (body.nil? || body.empty?) && (media.nil? || media.empty?)

        msg_context = context || @contexts.first || 'default'
        params = {
          'context'     => msg_context,
          'to_number'   => to,
          'from_number' => from
        }
        params['body']  = body if body
        params['media'] = media if media
        params['tags']  = tags if tags
        kwargs.each { |k, v| params[k.to_s] = v }

        result = execute('messaging.send', params)
        message_id = result['message_id'] || ''

        msg = Message.new(
          message_id:  message_id,
          context:     msg_context,
          direction:   'outbound',
          from_number: from,
          to_number:   to,
          body:        body || '',
          media:       media || [],
          state:       'queued',
          tags:        tags || []
        )
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

        # Add protocol to params if we have one (except for signalwire.connect)
        if @protocol && method != METHOD_SIGNALWIRE_CONNECT
          params = params.dup
          params['protocol'] = @protocol
        end

        msg = {
          'jsonrpc' => '2.0',
          'id'      => id,
          'method'  => method,
          'params'  => params
        }

        entry = { mutex: Mutex.new, cv: ConditionVariable.new, result: nil, error: nil }
        @pending_mutex.synchronize { @pending[id] = entry }

        _send_json(msg)

        # Wait for response (10s timeout to detect half-open connections)
        entry[:mutex].synchronize do
          deadline = Time.now + 10
          while entry[:result].nil? && entry[:error].nil?
            remaining = deadline - Time.now
            if remaining <= 0
              @pending_mutex.synchronize { @pending.delete(id) }
              raise RelayError.new(-1, "Request #{method} timed out")
            end
            entry[:cv].wait(entry[:mutex], remaining)
          end
        end

        @pending_mutex.synchronize { @pending.delete(id) }
        raise entry[:error] if entry[:error]

        result = entry[:result]

        # Check result code for non-connect methods
        if method != METHOD_SIGNALWIRE_CONNECT
          code = result['code']
          if code && !code.to_s.match?(/\A2\d\d\z/)
            raise RelayError.new(code, result['message'] || 'Unknown error')
          end
        end

        result
      end

      private

      # ------------------------------------------------------------------
      # WebSocket connection lifecycle
      # ------------------------------------------------------------------

      def _connect_and_run
        url = "wss://#{@host}"
        ready_mutex = Mutex.new
        ready_cv    = ConditionVariable.new
        ready_flag  = false
        ws_error    = nil

        client_ref = self

        @ws = WebSocket::Client::Simple.connect(url) do |ws|
          ws.on :open do
            client_ref.send(:_on_ws_open)
            ready_mutex.synchronize do
              ready_flag = true
              ready_cv.signal
            end
          end

          ws.on :message do |msg|
            client_ref.send(:_on_ws_message, msg.data)
          end

          ws.on :error do |e|
            ws_error = e
            ready_mutex.synchronize do
              ready_flag = true
              ready_cv.signal
            end
          end

          ws.on :close do |_e|
            client_ref.send(:_on_ws_close)
            ready_mutex.synchronize do
              ready_flag = true
              ready_cv.signal
            end
          end
        end

        # Wait for connection to open
        ready_mutex.synchronize do
          ready_cv.wait(ready_mutex, 15) until ready_flag
        end

        raise ws_error if ws_error

        @ws_mutex.synchronize { @connected = true }
        @reconnect_delay = RECONNECT_MIN_DELAY

        # Authenticate
        _authenticate

        # Keep reading until disconnected
        while @running && @connected
          sleep 1
        end
      end

      def _on_ws_open
        # Connection opened
      end

      def _on_ws_message(data)
        return if data.nil? || data.empty?

        begin
          msg = JSON.parse(data)
        rescue JSON::ParserError => e
          $stderr.puts "[RELAY] Failed to parse message: #{e.message}"
          return
        end

        _handle_message(msg)
      end

      def _on_ws_close
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

      def _authenticate
        params = {
          'version'    => PROTOCOL_VERSION,
          'agent'      => AGENT_STRING,
          'event_acks' => true
        }

        if @jwt_token
          params['authentication'] = { 'jwt_token' => @jwt_token }
        else
          params['authentication'] = {
            'project' => @project_id,
            'token'   => @token
          }
        end

        params['contexts'] = @contexts unless @contexts.empty?
        params['protocol'] = @protocol if @protocol && !@should_restart
        params['authorization_state'] = @authorization_state if @authorization_state && !@should_restart

        if @should_restart
          @protocol = nil
          @authorization_state = nil
          @should_restart = false
        end

        result = execute(METHOD_SIGNALWIRE_CONNECT, params)
        @protocol = result['protocol'] if result['protocol']
      end

      # ------------------------------------------------------------------
      # Message dispatch
      # ------------------------------------------------------------------

      def _handle_message(msg)
        method = msg['method']
        id     = msg['id']

        if method.nil?
          # This is a response to a pending request
          _handle_response(msg)
          return
        end

        case method
        when METHOD_SIGNALWIRE_EVENT
          _handle_event(msg)
        when METHOD_SIGNALWIRE_PING
          _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} })
        when METHOD_SIGNALWIRE_DISCONNECT
          _handle_disconnect(msg)
        else
          # Unknown method, send empty result
          _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} }) if id
        end
      end

      def _handle_response(msg)
        id = msg['id']
        return unless id

        entry = @pending_mutex.synchronize { @pending[id] }
        return unless entry

        if msg['error']
          err = msg['error']
          entry[:mutex].synchronize do
            entry[:error] = RelayError.new(err['code'], err['message'] || 'Unknown error')
            entry[:cv].signal
          end
        else
          entry[:mutex].synchronize do
            entry[:result] = msg['result'] || {}
            entry[:cv].signal
          end
        end
      end

      def _handle_event(msg)
        id = msg['id']
        outer_params = msg['params'] || {}

        # ACK the event immediately
        _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} }) if id

        event_type   = outer_params['event_type'] || ''
        event_params = outer_params['params'] || {}
        call_id      = event_params['call_id'] || ''

        # Authorization state
        if event_type == EVENT_AUTHORIZATION_STATE
          @authorization_state = event_params['authorization_state']
          return
        end

        # Inbound call
        if event_type == EVENT_CALL_RECEIVE
          _handle_inbound_call(outer_params)
          return
        end

        # Dial completion -- call_id is NESTED at params.call.call_id
        if event_type == EVENT_CALL_DIAL
          _handle_dial_event(outer_params)
          return
        end

        # Inbound message
        if event_type == EVENT_MESSAGING_RECEIVE
          _handle_inbound_message(outer_params)
          return
        end

        # Outbound message state
        if event_type == EVENT_MESSAGING_STATE
          _handle_message_state(outer_params)
          return
        end

        # State events during dial -- call not registered yet
        if event_type == EVENT_CALL_STATE
          tag = event_params['tag'] || ''
          has_pending = @dials_mutex.synchronize { @pending_dials.key?(tag) }
          if !tag.empty? && has_pending
            has_call = @calls_mutex.synchronize { @calls.key?(call_id) }
            unless has_call || call_id.empty?
              _register_dial_leg(tag, event_params)
            end
          end
          # Fall through to normal routing
        end

        # Normal routing by call_id
        unless call_id.empty?
          call = @calls_mutex.synchronize { @calls[call_id] }
          if call
            call._dispatch_event(outer_params)
            if call.state == CALL_STATE_ENDED
              @calls_mutex.synchronize { @calls.delete(call_id) }
            end
          end
        end
      end

      def _handle_disconnect(msg)
        id = msg['id']
        params = msg['params'] || {}

        # Respond with empty result
        _send_json({ 'jsonrpc' => '2.0', 'id' => id, 'result' => {} }) if id

        # Check restart flag
        @should_restart = params['restart'] == true

        # Let the connection close, reconnect will happen automatically
        @ws_mutex.synchronize { @connected = false }
      end

      def _handle_inbound_call(payload)
        event_params = payload['params'] || {}
        call = Call.new(
          self,
          call_id:    event_params['call_id'] || '',
          node_id:    event_params['node_id'] || '',
          project_id: event_params['project_id'] || '',
          context:    event_params['context'] || event_params['protocol'] || '',
          tag:        event_params['tag'] || '',
          direction:  event_params['direction'] || 'inbound',
          device:     event_params['device'] || {},
          state:      event_params['call_state'] || '',
          segment_id: event_params['segment_id'] || ''
        )

        @calls_mutex.synchronize { @calls[call.call_id] = call }

        if @on_call_handler
          Thread.new do
            begin
              @on_call_handler.call(call)
            rescue => e
              $stderr.puts "[RELAY] Error in on_call handler: #{e.message}"
            end
          end
        end
      end

      def _handle_dial_event(payload)
        event_params = payload['params'] || {}
        tag          = event_params['tag'] || ''
        dial_state   = event_params['dial_state'] || ''
        call_info    = event_params['call'] || {}

        entry = @dials_mutex.synchronize { @pending_dials[tag] }
        return unless entry

        if dial_state == 'answered'
          call_id = call_info['call_id'] || ''
          node_id = call_info['node_id'] || ''

          # Find or create the call
          call = @calls_mutex.synchronize { @calls[call_id] }
          unless call
            call = Call.new(
              self,
              call_id:    call_id,
              node_id:    node_id,
              project_id: @project_id,
              tag:        call_info['tag'] || tag,
              direction:  'outbound',
              device:     call_info['device'] || {},
              state:      CALL_STATE_ANSWERED
            )
            @calls_mutex.synchronize { @calls[call_id] = call }
          end
          call.state = CALL_STATE_ANSWERED

          entry[:mutex].synchronize do
            entry[:call] = call
            entry[:cv].signal
          end
        elsif dial_state == 'failed'
          entry[:mutex].synchronize do
            entry[:error] = 'Dial failed'
            entry[:cv].signal
          end
        end
      end

      def _register_dial_leg(tag, event_params)
        call_id = event_params['call_id'] || ''
        return if call_id.empty?

        call = Call.new(
          self,
          call_id:    call_id,
          node_id:    event_params['node_id'] || '',
          project_id: @project_id,
          tag:        tag,
          direction:  'outbound',
          device:     event_params['device'] || {},
          state:      event_params['call_state'] || ''
        )
        @calls_mutex.synchronize { @calls[call_id] = call }
      end

      def _handle_inbound_message(payload)
        event_params = payload['params'] || {}
        msg = Message.new(
          message_id:  event_params['message_id'] || '',
          context:     event_params['context'] || '',
          direction:   'inbound',
          from_number: event_params['from_number'] || '',
          to_number:   event_params['to_number'] || '',
          body:        event_params['body'] || '',
          media:       event_params['media'] || [],
          segments:    event_params['segments'] || 0,
          state:       event_params['message_state'] || 'received',
          tags:        event_params['tags'] || []
        )

        if @on_message_handler
          Thread.new do
            begin
              @on_message_handler.call(msg)
            rescue => e
              $stderr.puts "[RELAY] Error in on_message handler: #{e.message}"
            end
          end
        end
      end

      def _handle_message_state(payload)
        event_params = payload['params'] || {}
        message_id = event_params['message_id'] || ''

        msg = @messages_mutex.synchronize { @messages[message_id] }
        return unless msg

        msg._dispatch_event(payload)

        # Clean up terminal messages
        if msg.done?
          @messages_mutex.synchronize { @messages.delete(message_id) }
        end
      end

      def _reject_all_pending(reason)
        @pending_mutex.synchronize do
          @pending.each_value do |entry|
            entry[:mutex].synchronize do
              entry[:error] ||= RelayError.new(-1, reason)
              entry[:cv].signal
            end
          end
          @pending.clear
        end

        @dials_mutex.synchronize do
          @pending_dials.each_value do |entry|
            entry[:mutex].synchronize do
              entry[:error] ||= reason
              entry[:cv].signal
            end
          end
          @pending_dials.clear
        end
      end
    end
  end
end
