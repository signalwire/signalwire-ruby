# frozen_string_literal: true

# Copyright (c) 2026 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'base64'
require 'json'
require 'openssl'
require 'securerandom'
require 'uri'
require_relative '../error'
require_relative 'client'
require_relative 'rack_support'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Namespace holding the AI Chat client's error family, response models and
  # the browser-facing gateway.
  module AIChat
    # A request the gateway refused, with the HTTP status the browser should see.
    #
    # Deliberately coarse: the browser is told *that* it was refused and, at
    # most, which of a handful of buckets it fell into. Anything finer would let
    # a caller map out the caps and the allowlist by probing.
    #
    # A member of the +SignalWire::Error+ family (+rescue SignalWire::Error+
    # catches it).
    class GatewayRejection < SignalWire::Error
      # HTTP status to send back: 401 bad key, 403 origin/handle, 400 disallowed
      # method or malformed request, 413 a request, message or metadata over its
      # size limit, 429 a cap was hit.
      attr_reader :status

      # Short, fixed explanation. It reaches the browser, so it names only the
      # bucket: for a handle, "malformed handle" (it doesn't parse), "invalid
      # handle" (its signature doesn't verify) or "expired handle" (it verified
      # but is past its expiry), and never the caps' values or the allowlist.
      attr_reader :reason

      # @param status [Integer] the HTTP status the route should return
      # @param reason [String] the fixed, browser-safe explanation
      def initialize(status, reason)
        @status = status
        @reason = reason
        super("#{status}: #{reason}")
      end
    end

    # Server-side proxy that lets a browser chat without holding a token.
    #
    # A chat widget running in a page cannot hold a SignalWire API token: the
    # token carries the whole project, and every turn bills. So the widget talks
    # to a gateway mounted in your own app, which holds the credential
    # server-side and forwards on the widget's behalf:
    #
    #   browser ──(publishable key)──▶ your app ──(project:token)──▶ chat service
    #
    # The browser learns exactly two things: the gateway's URL and a publishable
    # key. Not the project, the space, the token, or which agent config runs —
    # the gateway injects +config_url+ itself, so a key can only ever reach the
    # one script it was issued for. Mount {#router} (a Rack app) beside your
    # agent:
    #
    #   gateway = SignalWire::AIChat::ChatGateway.new(
    #     config_url: 'https://my-agent.example.com/swml',
    #     key: 'pk_live_...',                        # what the widget carries
    #     allowed_origins: ['https://shop.example.com']
    #   )
    #   app = Rack::Builder.new do
    #     map('/chat') { run gateway.router }
    #     map('/') { run agent.rack_app }
    #   end
    #
    # == What a stolen key gets you
    #
    # Nothing to read: +chat_log+ is filtered to the visible dialogue, and a
    # conversation handle is signed by the gateway, so ids cannot be guessed or
    # enumerated. What it gets you is the ability to *talk*, which costs the
    # project money — so the caps are the primary control: +max_new_conversations+
    # and +max_turns+ bound the bill from both directions. The origin allowlist
    # is a second layer: it stops a key pasted into someone else's page, not
    # anyone using curl. Treat it as leak containment, not access control.
    #
    # == What the browser may volunteer
    #
    # Exactly one field is forwarded rather than overwritten: +user_meta_data+,
    # the page context a widget collects about itself. It reaches the agent's
    # config request as +params.user_meta_data+, but only on the call that
    # CREATES the conversation; it is browser-authored, so treat it as a
    # visitor's claim and never as authority.
    #
    # == Size limits
    #
    # The request body ({MAX_REQUEST_BODY_BYTES}, refused before it is parsed), a
    # chat message ({MAX_MESSAGE_BYTES} of UTF-8) and +user_meta_data+
    # ({MAX_USER_METADATA_BYTES} serialized) are each answered with 413 past
    # their limit.
    #
    # Counters live in this process (guarded by a Mutex, so a threaded Rack
    # server shares them safely). Behind several replicas each holds its own, so
    # the effective cap multiplies by replica count.
    class ChatGateway
      include RackSupport

      # Seconds a handle stays valid: outlives a page refresh, not a session left
      # open overnight.
      DEFAULT_HANDLE_TTL = 24 * 60 * 60

      # The chat service's own default conversation timeout, reported to the
      # browser when none is configured. The service owns the behaviour.
      SERVICE_DEFAULT_CONVERSATION_TIMEOUT = 3600

      # New conversations per window, per gateway.
      DEFAULT_MAX_NEW_CONVERSATIONS = 60

      # Turns per conversation, ever.
      DEFAULT_MAX_TURNS = 200

      # Length (seconds) of the window +max_new_conversations+ counts over.
      DEFAULT_WINDOW_SECONDS = 60

      # The browser-facing methods a request may name.
      ALLOWED_METHODS = Set['start', 'chat', 'log', 'end'].freeze

      # Bound on the browser-volunteered +user_meta_data+ bag, serialized.
      MAX_USER_METADATA_BYTES = 8 * 1024

      # Bound on one typed message, UTF-8 encoded: a chat turn here, and the text
      # a {HandoffRouter}'s +/say+ injects into a live call.
      MAX_MESSAGE_BYTES = 8 * 1024

      # Bound on a whole request body, checked before it is parsed.
      MAX_REQUEST_BODY_BYTES = 64 * 1024

      # Roles a browser may see in a replayed transcript.
      VISIBLE_ROLES = Set['user', 'assistant'].freeze

      # Hosts that never need listing, so local development works unconfigured.
      LOCAL_HOSTS = Set['localhost', '127.0.0.1', '::1', '[::1]'].freeze
      private_constant :LOCAL_HOSTS

      # The agent config this key may talk to; injected on every call.
      attr_reader :config_url

      # The publishable key the widget carries.
      attr_reader :key

      # Origins permitted to use this key (normalised, no trailing slash).
      attr_reader :allowed_origins

      # Seconds a signed handle stays valid.
      attr_reader :handle_ttl

      # Idle seconds before the service ends a conversation, or +nil+ for the
      # service default.
      attr_reader :conversation_timeout

      # Cap on conversations minted per window.
      attr_reader :max_new_conversations

      # Cap on turns per conversation.
      attr_reader :max_turns

      # Length of the window the mint cap counts over.
      attr_reader :window_seconds

      # Build a gateway that fronts one agent for browser traffic.
      #
      # @param config_url [String] SWML config the gateway always sends upstream.
      #   Required, and never taken from the request body.
      # @param key [String, nil] publishable key the browser presents; defaults to
      #   +SIGNALWIRE_CHAT_GATEWAY_KEY+, else a generated +pk_...+ key.
      # @param allowed_origins [Array<String>] origins permitted to call in;
      #   localhost is always allowed, every other origin must be listed.
      # @param client [SignalWire::AIChatClient, nil] client to reuse. Omit and the
      #   gateway builds (and owns) its own from the ambient credentials.
      # @param secret [String, nil] HMAC key for signing handles; defaults to
      #   +SIGNALWIRE_CHAT_GATEWAY_SECRET+, else random per process (handles then
      #   stop verifying across a restart or a second worker).
      # @param handle_ttl [Integer] seconds a signed handle stays valid
      # @param conversation_timeout [Integer, nil] idle seconds before the service
      #   ends a conversation; sent on every create and reported to the browser
      # @param max_new_conversations [Integer] conversations minted per window
      # @param max_turns [Integer] turns per conversation
      # @param window_seconds [Integer] window the mint cap counts over
      # @raise [ArgumentError] when +config_url+ is empty
      def initialize(config_url:, key: nil, allowed_origins: [], client: nil, secret: nil,
                     handle_ttl: DEFAULT_HANDLE_TTL, conversation_timeout: nil,
                     max_new_conversations: DEFAULT_MAX_NEW_CONVERSATIONS, max_turns: DEFAULT_MAX_TURNS,
                     window_seconds: DEFAULT_WINDOW_SECONDS)
        raise ArgumentError, 'config_url is required — it is what a key is scoped to.' if blank?(config_url)

        @config_url = config_url
        @key = resolve_key(key)
        @allowed_origins = allowed_origins.to_set { |o| o.to_s.sub(%r{/+\z}, '') }
        @handle_ttl = handle_ttl
        @conversation_timeout = conversation_timeout
        @max_new_conversations = max_new_conversations
        @max_turns = max_turns
        @window_seconds = window_seconds
        init_runtime(client, secret)
      end

      # Redacted inspect: NEVER print the HMAC handle-signing secret — the default
      # #inspect dumps every ivar, and whoever reads that secret from a log can
      # forge a handle for any conversation.
      def inspect
        "#<#{self.class.name} config_url=#{config_url.inspect} " \
          "allowed_origins=#{allowed_origins.to_a.inspect} secret=[REDACTED]>"
      end
      alias to_s inspect

      # Epoch SECONDS of the newest dated message, or +nil+ if nothing is dated.
      #
      # Bootstraps a browser's idle clock across a reload. The service stamps
      # messages in MICROseconds; this converts, because a 1000000x unit error
      # here is silent. Every role counts: the service's idle clock runs off any
      # write.
      #
      # @param messages [Array<Hash>, nil] the transcript as +chat_log+ returns it
      # @return [Float, nil]
      def self.last_activity(messages)
        newest = Array(messages).filter_map { |msg| message_timestamp(msg) }.max
        newest && (newest / 1_000_000.0)
      end

      # The transcript a browser may redraw, and nothing else.
      #
      # +chat_log+ hands back the conversation as the service holds it: the
      # substituted system prompt, tool calls and their results alongside the
      # dialogue. Only user and assistant turns with actual text survive, reduced
      # to role, content and (in epoch SECONDS) when they were said.
      #
      # @param messages [Array<Hash>, nil] the transcript as +chat_log+ returns it
      # @return [Array<Hash>]
      def self.visible_messages(messages)
        Array(messages).filter_map do |msg|
          next unless msg.is_a?(Hash) && VISIBLE_ROLES.include?(msg['role'])

          content = msg['content']
          next unless content.is_a?(String) && !content.strip.empty?

          entry = { 'role' => msg['role'], 'content' => content }
          ts = message_timestamp(msg)
          entry['timestamp'] = ts / 1_000_000.0 if ts
          entry
        end
      end

      # The positive Integer microsecond timestamp of one message, else nil.
      def self.message_timestamp(msg)
        ts = msg.is_a?(Hash) ? msg['timestamp'] : nil
        ts if ts.is_a?(Integer) && ts.positive?
      end
      private_class_method :message_timestamp

      # Idle seconds a conversation actually gets: the configured timeout, else
      # the service default — never +nil+, so a widget can always warn.
      #
      # @return [Integer]
      def effective_timeout
        truthy?(conversation_timeout) ? conversation_timeout : SERVICE_DEFAULT_CONVERSATION_TIMEOUT
      end

      # Release the upstream client, if this gateway built it. A client passed in
      # via +client:+ belongs to the caller and is left alone.
      #
      # @return [nil]
      def close
        @client.close if @owns_client
        nil
      end

      # ── Handles ──────────────────────────────────────────────────────

      # Issue a signed handle for a conversation (a new +chat-...+ id when none
      # is given).
      #
      # The browser never names a conversation; signing means a caller can only
      # present handles this gateway issued.
      #
      # @param conversation_id [String, nil]
      # @return [String] +<payload>.<signature>+, both unpadded URL-safe base64
      def mint_handle(conversation_id = nil)
        conversation_id ||= "chat-#{SecureRandom.urlsafe_base64(18)}"
        payload = "#{conversation_id}:#{Time.now.to_i + handle_ttl}"
        "#{b64(payload)}.#{b64(sign(payload))}"
      end

      # Return the conversation id inside a handle, or raise. Signature first,
      # expiry second, both before the id is trusted for anything.
      #
      # @param handle [String]
      # @return [String] the conversation id
      # @raise [GatewayRejection] 400 "malformed handle", 403 "invalid handle"
      #   or 403 "expired handle"
      def read_handle(handle)
        payload, given = decode_handle(handle)
        raise GatewayRejection.new(403, 'invalid handle') unless OpenSSL.secure_compare(given, sign(payload))

        conversation_id, expires_at = split_payload(payload)
        raise GatewayRejection.new(403, 'expired handle') if Time.now.to_f > expires_at

        conversation_id
      end

      # ── Guards ───────────────────────────────────────────────────────

      # Allow localhost always; anything else must be listed.
      #
      # A missing +Origin+ is allowed: browsers always send one for the
      # cross-origin POSTs this serves, so absence means a non-browser caller —
      # and refusing those would stop no attacker, who simply omits the header.
      #
      # @param origin [String, nil] the request's Origin header
      # @return [nil]
      # @raise [GatewayRejection] 403 for an origin that isn't allowed
      def check_origin(origin)
        return if origin.nil?

        host = origin_host(origin)
        return if LOCAL_HOSTS.include?(host) || host.end_with?('.localhost')
        return if allowed_origins.include?(origin.sub(%r{/+\z}, ''))

        raise GatewayRejection.new(403, 'origin not allowed')
      end

      # Verify the publishable key the browser sent, in constant time.
      #
      # @param presented [String, nil] the key from the request, or nil
      # @return [nil]
      # @raise [GatewayRejection] 401 when the key is missing or does not match
      def check_key(presented)
        return if presented.is_a?(String) && !presented.empty? && OpenSSL.secure_compare(presented, key)

        raise GatewayRejection.new(401, 'bad key')
      end

      # ── The proxied call ─────────────────────────────────────────────

      # Validate the page context a browser volunteered, or nil. Absent, null and
      # empty all collapse to nil.
      #
      # @param body [Hash] the request body
      # @return [Hash, nil]
      # @raise [GatewayRejection] 400 when it is not a JSON object or can't be
      #   serialized, 413 when it exceeds {MAX_USER_METADATA_BYTES}
      def read_user_metadata(body)
        raw = body['user_meta_data']
        return nil if raw.nil?
        raise GatewayRejection.new(400, 'user_meta_data must be an object') unless raw.is_a?(Hash)
        return nil if raw.empty?
        raise GatewayRejection.new(413, 'user_meta_data too large') if serialized_size(raw) > MAX_USER_METADATA_BYTES

        raw
      end

      # Validate a browser request and build the upstream JSON-RPC call.
      #
      # Everything the browser could use to widen its own access is either
      # rejected or overwritten here: the method must be a browser method, the
      # conversation comes from a signed handle, and +config_url+ is ours. The
      # single exception is +user_meta_data+, which is forwarded nested under its
      # own key. A chat message over {MAX_MESSAGE_BYTES} is refused with 413
      # before a conversation is minted or a turn charged.
      #
      # @param body [Hash] the request body (string or symbol keys)
      # @param origin [String, nil] the request's Origin header
      # @param key [String, nil] the presented publishable key
      # @return [Array(String, Hash, String)] +[method, params, minted_handle]+ —
      #   +minted_handle+ is set only on the call that created the conversation
      # @raise [GatewayRejection] when the request is refused
      def prepare(body, origin:, key:)
        check_key(key)
        check_origin(origin)
        body = body.transform_keys(&:to_s)
        method = body.fetch('method', 'chat')
        raise GatewayRejection.new(400, 'method not allowed') unless ALLOWED_METHODS.include?(method)

        user_metadata = read_user_metadata(body)
        check_message_size(method, body['message'])
        conversation_id, minted = resolve_conversation(method, body['handle'])
        build_call(method, conversation_id, body['message'], user_metadata) + [minted]
      end

      # ── Rack surface ─────────────────────────────────────────────────

      # A Rack app exposing this gateway. Mount it under a prefix with
      # +Rack::Builder#map+; it shares that prefix with a {HandoffRouter} through
      # +Rack::Cascade+ (any other path answers 404 with +X-Cascade: pass+).
      #
      # +POST /+ takes +{"method": "start"|"chat"|"log"|"end", "handle"?,
      # "message"?, "user_meta_data"?}+ with the key in +Authorization: Bearer+.
      # A chat streams the service's JSON-RPC response body through UNBUFFERED —
      # the service pads slow turns with keepalive whitespace so proxies do not
      # sever the connection, and collecting the body here would swallow that
      # padding. A newly minted handle rides back in the +X-Chat-Handle+ header,
      # which is why it can be sent before the body has been produced.
      # +OPTIONS /+ answers a CORS preflight. A body over
      # {MAX_REQUEST_BODY_BYTES} is answered with 413 without being parsed.
      #
      # @return [#call] the Rack application
      def router
        ->(env) { route(env) }
      end

      private

      # The client, secret and cap counters the public settings don't expose.
      def init_runtime(client, secret)
        @client = client || AIChatClient.new
        @owns_client = client.nil?
        secret = present(secret) || present(ENV.fetch('SIGNALWIRE_CHAT_GATEWAY_SECRET', nil)) ||
                 SecureRandom.bytes(32)
        @secret = secret.b
        @mints = []
        @turns = {}
        @lock = Mutex.new
      end

      # The given key, else SIGNALWIRE_CHAT_GATEWAY_KEY, else a generated one.
      def resolve_key(key)
        present(key) || present(ENV.fetch('SIGNALWIRE_CHAT_GATEWAY_KEY', nil)) ||
          "pk_#{SecureRandom.urlsafe_base64(24)}"
      end

      # Whether +value+ is nil or empty.
      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      # +value+ unless it is nil or empty.
      def present(value)
        blank?(value) ? nil : value
      end

      # The reference's truthiness for a JSON value: nil, false, 0 and empty
      # strings/collections are all "not given".
      def truthy?(value)
        return false if value.nil? || value == false
        return !value.zero? if value.is_a?(Numeric)

        !(value.respond_to?(:empty?) && value.empty?)
      end

      # HMAC-SHA256 of +payload+ under this gateway's secret.
      def sign(payload)
        OpenSSL::HMAC.digest('SHA256', @secret, payload)
      end

      # Unpadded URL-safe base64.
      def b64(raw)
        Base64.urlsafe_encode64(raw, padding: false)
      end

      # [payload, signature] decoded from a handle, or a 400 "malformed handle".
      def decode_handle(handle)
        raise ArgumentError unless handle.is_a?(String)

        raw, sep, sig = handle.partition('.')
        raise ArgumentError if sep.empty?

        [Base64.urlsafe_decode64(raw), Base64.urlsafe_decode64(sig)]
      rescue ArgumentError
        raise GatewayRejection.new(400, 'malformed handle')
      end

      # [conversation_id, expires_at] from a verified payload, or a 400.
      def split_payload(payload)
        conversation_id, sep, expires = payload.force_encoding(Encoding::UTF_8).rpartition(':')
        expires_at = Integer(expires, 10, exception: false)
        raise GatewayRejection.new(400, 'malformed handle') if sep.empty? || expires_at.nil? || !payload.valid_encoding?

        [conversation_id, expires_at]
      end

      # The lowercased host of an origin, or '' when it has none.
      def origin_host(origin)
        URI.parse(origin).hostname.to_s.downcase
      rescue URI::InvalidURIError
        ''
      end

      # Size of the bag serialized the way the reference measures it: compact,
      # with non-ASCII escaped as \uXXXX.
      def serialized_size(raw)
        JSON.generate(raw, ascii_only: true).bytesize
      rescue JSON::GeneratorError, TypeError
        raise GatewayRejection.new(400, 'user_meta_data must be JSON-serializable')
      end

      # Refuse a chat message over MAX_MESSAGE_BYTES (UTF-8) with 413.
      def check_message_size(method, message)
        return unless method == 'chat' && message.is_a?(String) && utf8_len(message) > MAX_MESSAGE_BYTES

        raise GatewayRejection.new(413, 'message too large')
      end

      # [conversation_id, minted_handle] — from the handle, or a fresh mint.
      def resolve_conversation(method, handle)
        return [read_handle(handle), nil] if truthy?(handle)
        raise GatewayRejection.new(400, "#{method} requires a handle") if %w[end log].include?(method)

        charge_mint
        minted = mint_handle
        [read_handle(minted), minted]
      end

      # [service_method, params] for a validated browser call.
      def build_call(method, conversation_id, message, user_metadata)
        case method
        when 'end' then ['end_conversation', { 'id' => conversation_id }]
        when 'log' then ['chat_log', { 'id' => conversation_id }]
        when 'start' then ['create_conversation', create_params(conversation_id, user_metadata)]
        else ['chat', chat_params(conversation_id, message, user_metadata)]
        end
      end

      # Opens the conversation with no user message, so the agent speaks first.
      def create_params(conversation_id, user_metadata)
        params = { 'id' => conversation_id, 'config_url' => config_url }
        params['conversation_timeout'] = conversation_timeout if truthy?(conversation_timeout)
        params['user_meta_data'] = user_metadata if user_metadata
        params
      end

      # config_url and the timeout on every chat, because any chat may be the one
      # that auto-creates; the bag too, since creation is the only time it's read.
      def chat_params(conversation_id, message, user_metadata)
        raise GatewayRejection.new(400, 'message is required') unless message.is_a?(String) && !message.strip.empty?

        charge_turn(conversation_id)
        params = { 'id' => conversation_id, 'message' => message, 'config_url' => config_url }
        params['conversation_timeout'] = conversation_timeout if truthy?(conversation_timeout)
        params['user_meta_data'] = user_metadata if user_metadata
        params
      end

      # Monotonic clock seconds, for the cap windows.
      def monotonic
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Count a new conversation against the window limit, or reject with 429.
      def charge_mint
        @lock.synchronize do
          now = monotonic
          @mints.select! { |t| t > now - window_seconds }
          raise GatewayRejection.new(429, 'too many new conversations') if @mints.length >= max_new_conversations

          @mints << now
        end
      end

      # Count a turn against the conversation's limit, or reject with 429. Swept
      # here rather than on a timer: a handle cannot outlive its TTL.
      def charge_turn(conversation_id)
        @lock.synchronize do
          now = monotonic
          @turns.select! { |_, (_, at)| at > now - handle_ttl }
          count = @turns.fetch(conversation_id, [0, now]).first
          raise GatewayRejection.new(429, 'conversation turn limit reached') if count >= max_turns

          @turns[conversation_id] = [count + 1, now]
        end
      end

      # ── Rack dispatch ────────────────────────────────────────────────

      def route(env)
        return cascade_response unless route_path(env).empty?

        case env['REQUEST_METHOD']
        when 'OPTIONS' then preflight(env['HTTP_ORIGIN'])
        when 'POST' then proxy(env)
        else [405, { 'content-type' => 'application/json' }, [JSON.generate('error' => 'method not allowed')]]
        end
      end

      # CORS headers for an allowed origin, and none otherwise.
      def cors_headers(origin)
        return {} if origin.nil?

        check_origin(origin)
        { 'access-control-allow-origin' => origin, 'access-control-expose-headers' => 'X-Chat-Handle',
          'vary' => 'Origin' }
      rescue GatewayRejection
        {}
      end

      # 204, with allow headers only for an allowed origin.
      def preflight(origin)
        headers = cors_headers(origin)
        unless headers.empty?
          headers.merge!('access-control-allow-headers' => 'Authorization, Content-Type',
                         'access-control-allow-methods' => 'POST, OPTIONS', 'access-control-max-age' => '600')
        end
        [204, headers, []]
      end

      # Validate a browser request and forward it to the chat service. A refusal
      # is answered here; an upstream failure is not the browser's bad request,
      # so #dispatch runs outside the rescue and propagates to the server.
      def proxy(env)
        cors = cors_headers(env['HTTP_ORIGIN'])
        prepared, refusal = prepare_or_refuse(env, cors)
        return refusal if refusal

        method, params, minted = prepared
        cors['x-chat-handle'] = minted if minted
        dispatch(method, params, cors)
      end

      # [prepared_call, nil], or [nil, the Rack response refusing it].
      def prepare_or_refuse(env, cors)
        [prepare_request(env), nil]
      rescue GatewayRejection => e
        [nil, json_response(e.status, { 'error' => e.reason }, cors)]
      rescue StandardError
        [nil, json_response(400, { 'error' => 'bad request' }, cors)]
      end

      # Read and prepare one browser POST; raises GatewayRejection to refuse it.
      def prepare_request(env)
        body = read_json_body(env)
        raise GatewayRejection.new(400, 'body must be an object') unless body.is_a?(Hash)

        prepare(body, origin: env['HTTP_ORIGIN'], key: bearer_key(env['HTTP_AUTHORIZATION'].to_s))
      end

      # The key from an +Authorization: Bearer+ header, or nil.
      def bearer_key(auth)
        auth[7..] if auth.downcase.start_with?('bearer ')
      end

      # Run the upstream call for a prepared request. Outside the rescue in
      # #proxy on purpose: an upstream failure is not the browser's bad request.
      def dispatch(method, params, headers)
        case method
        when 'end_conversation' then respond_end(params, headers)
        when 'create_conversation' then respond_create(params, headers)
        when 'chat_log' then respond_log(params, headers)
        else [200, { 'content-type' => 'application/json' }.merge(headers), stream(method, params)]
        end
      end

      # A Rack body that relays the service's response chunk by chunk as Rack
      # iterates it — nothing is requested upstream until then, and nothing is
      # collected.
      def stream(method, params)
        client = @client
        Enumerator.new do |out|
          client.raw_post(method, params) { |response| response.read_body { |chunk| out << chunk } }
        end
      end

      # End the conversation upstream and confirm it.
      def respond_end(params, headers)
        @client.end(params['id'])
        json_response(200, { 'status' => 'ended' }, headers)
      end

      # Create the conversation upstream and answer with its greeting and timeout.
      def respond_create(params, headers)
        info = @client.create_conversation(params['id'], config_url: params['config_url'],
                                                         timeout: params['conversation_timeout'],
                                                         user_metadata: params['user_meta_data'])
        json_response(200, { 'greeting' => info.initial_message, 'status' => info.status,
                             'timeout' => effective_timeout }, headers)
      end

      # last_activity is computed from the raw transcript, the only place every
      # role's timestamp still exists.
      def respond_log(params, headers)
        log = @client.log(params['id'])
        json_response(200, { 'messages' => self.class.visible_messages(log.messages), 'timeout' => effective_timeout,
                             'last_activity' => self.class.last_activity(log.messages) }, headers)
      end
    end
  end
end
