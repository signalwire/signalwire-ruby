# frozen_string_literal: true

# Copyright (c) 2026 SignalWire
#
# This file is part of the SignalWire SDK.
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'net/http'
require 'json'
require 'uri'
require 'base64'
require_relative '../version'
require_relative '../error'

# SignalWire — root namespace of the Ruby SDK.
module SignalWire
  # Namespace holding the AI Chat client's error family and response models.
  #
  # {SignalWire::AIChatClient} speaks the standard SignalWire front-door protocol:
  # HTTP Basic +project:api_token+ with the space in the hostname —
  # +POST https://{space}.signalwire.com/api/ai/chat+ — carrying a JSON-RPC 2.0
  # body whose params are pure payload (identity NEVER appears in the body; it
  # rides the Basic-auth header only).
  #
  # A +chat+ call awaits a full LLM round trip (seconds, not milliseconds). The
  # service streams keepalive whitespace ahead of a slow response body (proxy
  # read-timeout protection), so liveness is byte-driven rather than wall-clock:
  # there is no total-request timeout an idle turn could trip — only a per-read
  # idle timeout, mirroring the python reference's
  # +aiohttp.ClientTimeout(total=None, connect=10, sock_read=60)+. Leading
  # whitespace is valid JSON, so the buffered +JSON.parse+ is unaffected.
  #
  # Mirrors the python reference +signalwire.ai_chat.AIChatClient+.
  #
  #   require 'signalwire/ai_chat'
  #
  #   client = SignalWire::AIChatClient.new(space: 'myspace') # env supplies creds
  #   client.create_conversation('conv-1', config_url: CONFIG_URL)
  #   reply = client.chat('conv-1', 'hello')
  #   puts reply.text
  module AIChat
    # Default endpoint path appended to a +space+-derived base URL.
    DEFAULT_PATH = '/api/ai/chat'

    # Connect timeout (seconds) — a bounded TCP/TLS handshake. Mirrors the python
    # reference's +connect=10+.
    DEFAULT_CONNECT_TIMEOUT_SECONDS = 10

    # Idle read timeout (seconds) for a single request. The service streams
    # keepalive whitespace roughly every 10s, so this bounds true byte-silence (a
    # dead connection), NOT total turn length — mirroring the python reference's
    # +sock_read=60+. Net::HTTP's +read_timeout+ is per-read (it resets on each
    # received chunk), so the streaming proxy's heartbeat keeps a live-but-slow
    # turn alive while a truly dead connection is severed after this many seconds
    # of silence. A total wall-clock cap is deliberately absent — a slow-but-live
    # turn must never be severed by the client.
    DEFAULT_READ_IDLE_TIMEOUT_SECONDS = 60

    # ── Errors ─────────────────────────────────────────────────────────

    # Base error for AI Chat service failures. Every typed subclass carries the
    # JSON-RPC error +code+ (or +nil+ when the failure rode the success envelope,
    # as with {SummaryError}) and the server +message+.
    #
    # A member of the +SignalWire::Error+ family, so a caller can rescue the whole
    # SDK with +rescue SignalWire::Error+; catch this one family
    # (+rescue SignalWire::AIChat::AIChatError+) for every AI-Chat failure and
    # branch on +#code+ or the subclass type.
    class AIChatError < SignalWire::Error
      # JSON-RPC error code, or +nil+ when the failure rode the success envelope.
      attr_reader :code

      # The server-provided error message (without the +[code]+ prefix).
      attr_reader :server_message

      def initialize(code, message)
        @code = code
        @server_message = message
        super("[#{code}] #{message}")
      end
    end

    # Missing/rejected identity (HTTP 401 / JSON-RPC -32009).
    class AuthenticationError < AIChatError; end

    # The conversation does not exist in this project (-32001).
    class ConversationNotFoundError < AIChatError; end

    # Project or conversation rate limit hit (-32005 / -32006).
    class RateLimitError < AIChatError; end

    # Another message is being processed for this conversation (-32007).
    class ChatInProgressError < AIChatError; end

    # Summary generation failed. +summarize+ returns EXACTLY ONE of +{summary}+
    # (success) or +{error}+ (generation failed), and the failure rides the
    # JSON-RPC *success* envelope — not an +error+ object — so it never reaches
    # the error-code mapping. Surfaced here so a failed summary can't masquerade
    # as an empty string. +code+ is +nil+ (no JSON-RPC code).
    class SummaryError < AIChatError; end

    # JSON-RPC error code → the typed error class it maps to. An unmapped code
    # falls to the base {AIChatError}.
    ERROR_BY_CODE = {
      -32_001 => ConversationNotFoundError,
      -32_005 => RateLimitError,
      -32_006 => RateLimitError,
      -32_007 => ChatInProgressError,
      -32_009 => AuthenticationError
    }.freeze

    # ── Response models ────────────────────────────────────────────────

    # Result of {AIChatClient#create_conversation}.
    ConversationInfo = Struct.new(:id, :status, :initial_message, keyword_init: true)

    # Result of {AIChatClient#chat}.
    ChatResponse = Struct.new(:text, :conversation_id, :user_event, keyword_init: true)

    # Result of {AIChatClient#log}.
    ChatLog = Struct.new(:messages, :call_timeline, keyword_init: true)
  end

  # Client for the SignalWire AI Chat service. See {SignalWire::AIChat} for the
  # protocol overview and the error family / response models.
  class AIChatClient
    include AIChat

    # AI-Chat User-Agent. Product token stays stable at +signalwire-ruby+; the
    # version segment is the real SDK version so it can never drift from a
    # hardcoded literal (mirrors the REST client's USER_AGENT).
    USER_AGENT = "signalwire-ruby/#{SignalWire::VERSION}".freeze

    # Fully-qualified endpoint URL requests are POSTed to.
    attr_reader :url

    # +project+ / +token+ default to the +SIGNALWIRE_PROJECT_ID+ /
    # +SIGNALWIRE_API_TOKEN+ environment variables. The target URL resolves in
    # order:
    #   1. an explicit +url:+ (used verbatim, highest precedence);
    #   2. +RAILS_DEV_MODE+ when it holds a real URL (it doubles as the service's
    #      persona switch, so a plain boolean like "true"/"1" means "on" WITHOUT
    #      carrying a URL and does NOT override the target);
    #   3. +https://{space}.signalwire.com/api/ai/chat+ from +space:+ (or
    #      +SIGNALWIRE_SPACE+).
    #
    # +connect_timeout+ / +read_idle_timeout+ default to
    # {AIChat::DEFAULT_CONNECT_TIMEOUT_SECONDS} /
    # {AIChat::DEFAULT_READ_IDLE_TIMEOUT_SECONDS}; the read timeout is per-read
    # byte-silence (see {AIChat::DEFAULT_READ_IDLE_TIMEOUT_SECONDS}), NOT a total
    # turn cap. A +read_idle_timeout+ of +0+/+nil+ disables the read timeout.
    def initialize(project: nil, token: nil, space: nil, url: nil,
                   connect_timeout: DEFAULT_CONNECT_TIMEOUT_SECONDS,
                   read_idle_timeout: DEFAULT_READ_IDLE_TIMEOUT_SECONDS)
      @project = require_project(project)
      @token   = token || ENV.fetch('SIGNALWIRE_API_TOKEN', '')
      space    ||= ENV.fetch('SIGNALWIRE_SPACE', '')

      @url = self.class.resolve_url(url, space)
      @auth_header = "Basic #{Base64.strict_encode64("#{@project}:#{@token}")}"
      @connect_timeout = connect_timeout
      @read_idle_timeout = read_idle_timeout
      @request_counter = 0
    end

    # Redacted inspect: NEVER print the raw API token or the derived Basic-auth
    # header (which embeds the token) — the default #inspect dumps every ivar,
    # leaking the token into logs / crash dumps / a REPL session.
    def inspect
      "#<#{self.class.name} url=#{@url.inspect} project=#{@project.inspect} token=[REDACTED]>"
    end
    alias to_s inspect

    # Resolve the target URL (see #initialize). Public for testability; static —
    # takes no client state.
    def self.resolve_url(url, space)
      return url if url && !url.empty?

      dev_url = ENV.fetch('RAILS_DEV_MODE', '').strip
      # RAILS_DEV_MODE doubles as the service's persona switch, so plain booleans
      # mean "on" without carrying a URL — only a real URL-looking value overrides
      # the target here.
      booleans = %w[false 0 no off true 1 yes on]
      return dev_url if !dev_url.empty? && !booleans.include?(dev_url.downcase)

      return "https://#{space}.signalwire.com#{DEFAULT_PATH}" if space && !space.empty?

      raise ArgumentError,
            'No service URL: provide url:, set RAILS_DEV_MODE to a full URL, ' \
            'or provide space: / SIGNALWIRE_SPACE.'
    end

    # Release any client-held resources. The reference closes its persistent
    # aiohttp session here; Ruby's AIChatClient opens a fresh Net::HTTP
    # connection per request and owns no long-lived session, so there is nothing
    # to release — this is a well-defined no-op that completes the lifecycle
    # contract (mirrors the reference #close). Safe to call any number of times.
    def close; end

    # ── API methods ──────────────────────────────────────────────────

    # Create a conversation (or, with +reinit+, reinitialize an existing one) and
    # optionally send its opening user message. Returns a {AIChat::ConversationInfo}.
    def create_conversation(conversation_id, config_url:, user_message: nil,
                            timeout: nil, user_metadata: nil, reinit: false)
      params = { 'id' => conversation_id, 'config_url' => config_url }.merge(
        optional('user_message' => user_message, 'conversation_timeout' => timeout,
                 'user_meta_data' => user_metadata, 'reinit' => (true if reinit))
      )
      result = request('create_conversation', params)
      ConversationInfo.new(
        id: conversation_id,
        status: result['status'].is_a?(String) ? result['status'] : 'created',
        initial_message: result['initial_message']
      )
    end

    # Send a message and await a full LLM round trip. Returns a
    # {AIChat::ChatResponse}.
    #
    # Passing +config_url+ auto-creates the conversation if it doesn't exist yet;
    # +timeout+ and +reinit+ apply to that auto-create, with the same meaning as
    # on {#create_conversation}. Expect seconds — the turn awaits the model.
    def chat(conversation_id, message, role: 'user', config_url: nil,
             user_metadata: nil, timeout: nil, reinit: false)
      params = { 'id' => conversation_id, 'message' => message, 'role' => role }.merge(
        optional('config_url' => config_url, 'user_meta_data' => user_metadata,
                 'conversation_timeout' => timeout, 'reinit' => (true if reinit))
      )
      result = request('chat', params)
      ChatResponse.new(
        text: result['response'].is_a?(String) ? result['response'] : '',
        conversation_id: conversation_id,
        user_event: result['user_event'].is_a?(Hash) ? result['user_event'] : nil
      )
    end

    # End a conversation (triggers server-side post-processing / archival).
    # Returns +true+ when the service reported the conversation ended.
    def end(conversation_id)
      result = request('end_conversation', { 'id' => conversation_id })
      result['status'] == 'ended'
    end

    # Permanently delete a conversation and its data. Idempotent. Returns +true+
    # when the service reported the conversation deleted.
    def delete(conversation_id)
      result = request('delete', { 'id' => conversation_id })
      result['status'] == 'deleted'
    end

    # Return the full message history plus the call timeline as a
    # {AIChat::ChatLog}.
    def log(conversation_id)
      result = request('chat_log', { 'id' => conversation_id })
      ChatLog.new(
        messages: result['chat_log'].is_a?(Array) ? result['chat_log'] : [],
        call_timeline: result['call_timeline'].is_a?(Array) ? result['call_timeline'] : []
      )
    end

    # Return an AI summary of the conversation (rate limited server-side).
    #
    # The service returns EXACTLY ONE of +{summary}+ or +{error}+ — BOTH on the
    # success envelope — so a failed generation surfaces as a raised
    # {AIChat::SummaryError}, NEVER as an empty string. Optional +summary_prompt+
    # and sampling params (+temperature+/+top_p+/+frequency_penalty+/
    # +presence_penalty+/+max_tokens+) ride on the wire when given.
    def summarize(conversation_id, summary_prompt: nil, temperature: nil, top_p: nil,
                  frequency_penalty: nil, presence_penalty: nil, max_tokens: nil)
      params = { 'id' => conversation_id }.merge(
        optional('summary_prompt' => summary_prompt, 'temperature' => temperature, 'top_p' => top_p,
                 'frequency_penalty' => frequency_penalty, 'presence_penalty' => presence_penalty,
                 'max_tokens' => max_tokens)
      )
      result = request('summarize', params)
      raise SummaryError.new(nil, result['error'].to_s) if result.key?('error') && !result.key?('summary')

      summary = result['summary']
      summary.is_a?(String) ? summary : summary.to_s
    end

    private

    # The project id from the argument or +SIGNALWIRE_PROJECT_ID+; raises when
    # neither supplies one (project is the Basic-auth username, always required).
    def require_project(project)
      resolved = project || ENV.fetch('SIGNALWIRE_PROJECT_ID', '')
      return resolved unless resolved.nil? || resolved.empty?

      raise ArgumentError,
            'project is required. Provide it as an argument or set the ' \
            'SIGNALWIRE_PROJECT_ID environment variable.'
    end

    # Drop keys whose value is +nil+, so only the wire params the caller actually
    # supplied ride on the request (the SDK never sends an unset optional param).
    def optional(pairs)
      pairs.compact
    end

    # POST one JSON-RPC call and return its decoded +result+ object (a Hash).
    #
    # Success/failure is decided by the JSON-RPC BODY, not the HTTP status: the
    # service's keepalive heartbeat commits +200+ before the turn's outcome is
    # known, so a slow error can arrive as +200 + {"error": …}+. Never gate on the
    # HTTP status here (mirrors the python reference).
    #
    # Raises {AIChat::AIChatError} (or a typed subclass) when the body carries
    # +error+.
    def request(method, params)
      @request_counter += 1
      payload = { 'jsonrpc' => '2.0', 'method' => method, 'params' => params,
                  'id' => "req-#{@request_counter}" }
      response = perform(payload)
      body = parse_body(response)

      raise_for_error(body['error']) if body.is_a?(Hash) && !body['error'].nil?

      result = body.is_a?(Hash) ? body['result'] : nil
      result.is_a?(Hash) ? result : {}
    end

    # Buffer the whole body then parse. Leading keepalive whitespace is valid
    # JSON, so a plain parse handles it — no need to strip.
    def parse_body(response)
      JSON.parse(response.body || '')
    rescue JSON::ParserError
      raise AIChatError.new(response.code.to_i, "non-JSON response (HTTP #{response.code})")
    end

    # Raise the typed error for a JSON-RPC +error+ object. An unmapped (or absent)
    # code falls to the base {AIChat::AIChatError}.
    def raise_for_error(error)
      error = {} unless error.is_a?(Hash)
      code = error['code'].is_a?(Integer) ? error['code'] : nil
      klass = code ? (ERROR_BY_CODE[code] || AIChatError) : AIChatError
      raise klass.new(code, error['message'] || '')
    end

    # Issue one HTTP POST to the endpoint.
    def perform(payload)
      uri = URI(@url)
      req = build_request(uri, payload)
      build_http(uri).request(req)
    end

    # Build the Net::HTTP transport. +read_timeout+ is per-read byte-silence
    # (Net::HTTP resets it on each received chunk), NOT a total turn cap — a
    # live-but-slow turn kept alive by the proxy heartbeat never trips it.
    def build_http(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = @connect_timeout if @connect_timeout
      http.read_timeout = @read_idle_timeout if @read_idle_timeout&.positive?
      http.max_retries = 0
      http
    end

    def build_request(uri, payload)
      req = Net::HTTP::Post.new(uri)
      req['Authorization'] = @auth_header
      req['Content-Type']  = 'application/json'
      req['Accept']        = 'application/json'
      req['User-Agent']    = USER_AGENT
      req.body = JSON.generate(payload)
      req
    end
  end
end
