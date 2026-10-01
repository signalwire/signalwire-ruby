# frozen_string_literal: true

# ChatGateway: what a browser holding a publishable key can and cannot do.
#
# The gateway exists so a widget never holds a SignalWire API token. These tests
# pin the boundary that makes that safe — what the browser may name, what the
# gateway overwrites, and what the caps bound — against an in-process stub chat
# service reached over real HTTP (the real Net::HTTP path, no stubbed transport).
#
# Ported from signalwire-python tests/unit/ai_chat/test_gateway.py and the
# handle-rejection half of tests/unit/ai_chat/test_documented_limits.py.

require 'minitest/autorun'
require 'socket'
require 'json'
require 'rack'
require 'rack/mock'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire/ai_chat'

# An in-process chat service over a real socket. Records every JSON-RPC body the
# gateway forwarded upstream and answers with a canned result — or, in +slow+
# mode, pads the reply with keepalive whitespace written in separate chunks, the
# way the real service's heartbeat does on a slow turn.
class StubChatService
  CANNED = {
    'chat' => { 'response' => 'hi there' },
    'create_conversation' => { 'status' => 'created', 'initial_message' => 'Hi, I am Sigmond.' },
    'chat_log' => {
      'chat_log' => [
        { 'role' => 'system', 'content' => 'secret prompt' },
        { 'role' => 'user', 'content' => 'hi' },
        { 'role' => 'assistant', 'content' => 'hi there' }
      ]
    }
  }.freeze

  attr_reader :seen

  def initialize(slow: false)
    @slow = slow
    @seen = []
    @server = TCPServer.new('127.0.0.1', 0)
    @thread = Thread.new { serve_loop }
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}/"
  end

  def stop
    @server.close
    @thread.kill
  end

  private

  def serve_loop
    loop do
      conn = @server.accept
      handle(conn)
    rescue IOError, Errno::EBADF
      break
    end
  end

  def handle(conn)
    return if conn.gets.nil?

    body = JSON.parse(conn.read(read_headers(conn)['content-length'].to_i))
    @seen << body
    @slow ? reply_slow(conn, body) : reply(conn, body)
  ensure
    conn.close
  end

  def read_headers(conn)
    headers = {}
    while (line = conn.gets) && line != "\r\n"
      name, value = line.split(':', 2)
      headers[name.strip.downcase] = value.strip if value
    end
    headers
  end

  def reply(conn, body)
    result = CANNED.fetch(body['method'], { 'status' => 'ended' })
    out = JSON.generate('jsonrpc' => '2.0', 'result' => result, 'id' => body['id'])
    conn.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
               "Content-Length: #{out.bytesize}\r\nConnection: close\r\n\r\n#{out}")
  end

  def reply_slow(conn, body)
    conn.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" \
               "Transfer-Encoding: chunked\r\nConnection: close\r\n\r\n")
    3.times do
      write_chunk(conn, ' ' * 16)
      sleep 0.02
    end
    write_chunk(conn, JSON.generate('jsonrpc' => '2.0', 'result' => { 'response' => 'slow reply' },
                                    'id' => body['id']))
    conn.write("0\r\n\r\n")
  end

  def write_chunk(conn, data)
    conn.write("#{data.bytesize.to_s(16)}\r\n#{data}\r\n")
    conn.flush
  end
end

module GatewayTestHelper
  CONFIG_URL = 'https://agent.example.com/swml'
  KEY = 'pk_test_key'
  ORIGIN = 'https://shop.example.com'
  HEADERS = { 'HTTP_AUTHORIZATION' => "Bearer #{KEY}", 'HTTP_ORIGIN' => ORIGIN }.freeze
  Gateway = SignalWire::AIChat::ChatGateway
  Rejection = SignalWire::AIChat::GatewayRejection

  def setup
    @service = StubChatService.new
    @gateway = make_gateway(allowed_origins: [ORIGIN], secret: 'test-secret')
  end

  def teardown
    @service&.stop
  end

  # A gateway wired to the stub service. Construction is fail-fast on
  # credentials, so every gateway gets a client.
  def make_gateway(service: @service, **opts)
    opts[:secret] ||= 's'
    client = SignalWire::AIChatClient.new(project: 'p', token: 't', url: service.url)
    Gateway.new(config_url: CONFIG_URL, key: KEY, client: client, **opts)
  end

  def prep(body, gateway: @gateway, origin: ORIGIN)
    gateway.prepare(body, origin: origin, key: KEY)
  end

  # The gateway router mounted at /chat, driven in process.
  def http(gateway = @gateway)
    app = gateway.router
    Rack::MockRequest.new(Rack::Builder.new { map('/chat') { run app } }.to_app)
  end

  def post(gateway, body, headers = HEADERS)
    http(gateway).post('/chat/', headers.merge(input: JSON.generate(body), 'CONTENT_TYPE' => 'application/json'))
  end

  def assert_rejected(status = nil, &)
    err = assert_raises(Rejection, &)
    assert_equal status, err.status if status
    err
  end
end

class ChatGatewayHandleTest < Minitest::Test
  include GatewayTestHelper

  def test_a_handle_round_trips
    assert @gateway.read_handle(@gateway.mint_handle).start_with?('chat-')
  end

  # The whole reason the gateway mints: with a publishable key, a guessable id
  # would be enough to continue somebody else's chat.
  def test_the_browser_cannot_forge_a_conversation
    tampered = "#{@gateway.mint_handle.split('.').first}.AAAA"

    assert_rejected(403) { @gateway.read_handle(tampered) }
  end

  def test_a_handle_from_another_gateway_is_refused
    other = make_gateway(secret: 'different')

    assert_rejected { @gateway.read_handle(other.mint_handle) }
  end

  def test_an_expired_handle_is_refused
    gw = make_gateway(handle_ttl: -1)

    assert_rejected(403) { gw.read_handle(gw.mint_handle) }
  end

  def test_garbage_is_refused_without_leaking_why
    ['', 'not-a-handle', 'a.b.c', '!!!.!!!'].each do |bad|
      assert_rejected { @gateway.read_handle(bad) }
    end
  end

  def test_a_non_string_handle_is_malformed
    err = assert_rejected(400) { @gateway.read_handle(5) }

    assert_equal 'malformed handle', err.reason
  end

  def test_a_handle_names_the_conversation_it_was_minted_for
    assert_equal 'conv-root.5', @gateway.read_handle(@gateway.mint_handle('conv-root.5'))
  end
end

# The rejection reasons the documentation promises (test_documented_limits.py).
class ChatGatewayHandleRejectionReasonTest < Minitest::Test
  include GatewayTestHelper

  def test_malformed_handle
    err = assert_rejected { @gateway.read_handle('not-a-handle') }

    assert_equal [400, 'malformed handle'], [err.status, err.reason]
  end

  def test_invalid_handle
    tampered = "#{@gateway.mint_handle.split('.').first}.AAAA"
    err = assert_rejected { @gateway.read_handle(tampered) }

    assert_equal [403, 'invalid handle'], [err.status, err.reason]
  end

  def test_expired_handle
    gw = make_gateway(handle_ttl: -1)
    err = assert_rejected { gw.read_handle(gw.mint_handle) }

    assert_equal [403, 'expired handle'], [err.status, err.reason]
  end

  def test_the_browser_receives_the_reason
    gw = make_gateway(handle_ttl: -1)
    r = post(gw, { 'method' => 'chat', 'message' => 'hi', 'handle' => gw.mint_handle },
             { 'HTTP_AUTHORIZATION' => "Bearer #{KEY}" })

    assert_equal 403, r.status
    assert_equal({ 'error' => 'expired handle' }, JSON.parse(r.body))
  end

  def test_rejection_is_part_of_the_signalwire_error_family
    err = Rejection.new(429, 'too many new conversations')

    assert_kind_of SignalWire::Error, err
    assert_equal '429: too many new conversations', err.message
  end
end

class ChatGatewayOriginAndKeyTest < Minitest::Test
  include GatewayTestHelper

  # `gem install` → run → it works, without shipping open by default.
  def test_localhost_never_needs_listing
    ['http://localhost:3000', 'http://127.0.0.1:8080', 'http://app.localhost', 'http://[::1]:9000'].each do |origin|
      assert_nil @gateway.check_origin(origin)
    end
    # ...and the exemption is localhost-specific, not open-by-default.
    assert_rejected { @gateway.check_origin('https://evil.example.com') }
  end

  def test_a_listed_origin_is_allowed
    assert_nil @gateway.check_origin(ORIGIN)
    assert_nil @gateway.check_origin("#{ORIGIN}/")
    # A near-miss must not pass: a full-origin match, not a prefix one.
    assert_rejected { @gateway.check_origin('https://shop.example.com.evil.test') }
  end

  # The case this actually defends: a key pasted into someone else's page.
  def test_an_unlisted_origin_is_refused
    assert_rejected(403) { @gateway.check_origin('https://evil.example.com') }
  end

  # Absence means a non-browser caller; refusing it would stop no attacker.
  def test_a_missing_origin_is_allowed
    assert_nil @gateway.check_origin(nil)
    assert_rejected { @gateway.check_origin('https://evil.example.com') }
  end

  def test_allowed_origins_are_normalised_without_a_trailing_slash
    gw = make_gateway(allowed_origins: ['https://a.example/', 'https://b.example'])

    assert_equal Set['https://a.example', 'https://b.example'], gw.allowed_origins
  end

  def test_the_key_is_required
    [nil, '', 'pk_wrong'].each do |bad|
      assert_rejected(401) { @gateway.check_key(bad) }
    end
    assert_nil @gateway.check_key(KEY)
  end

  def test_config_url_is_required
    assert_raises(ArgumentError) { Gateway.new(config_url: '', client: @gateway.instance_variable_get(:@client)) }
  end

  def test_a_key_is_generated_when_none_is_given
    client = SignalWire::AIChatClient.new(project: 'p', token: 't', url: @service.url)
    saved = ENV.delete('SIGNALWIRE_CHAT_GATEWAY_KEY')
    gw = Gateway.new(config_url: CONFIG_URL, client: client)

    assert_match(/\Apk_[A-Za-z0-9_-]{32}\z/, gw.key)
  ensure
    ENV['SIGNALWIRE_CHAT_GATEWAY_KEY'] = saved if saved
  end

  def test_settings_are_readable
    gw = make_gateway(handle_ttl: 60, conversation_timeout: 900, max_new_conversations: 3,
                      max_turns: 4, window_seconds: 5)

    assert_equal [CONFIG_URL, KEY, 60, 900, 3, 4, 5],
                 [gw.config_url, gw.key, gw.handle_ttl, gw.conversation_timeout,
                  gw.max_new_conversations, gw.max_turns, gw.window_seconds]
  end
end

class ChatGatewayPrepareTest < Minitest::Test
  include GatewayTestHelper

  # If the browser could name it, whoever holds a key picks which agent runs.
  def test_config_url_is_ours_not_theirs
    _, params, = prep({ 'message' => 'hi', 'config_url' => 'https://evil/swml' })

    assert_equal CONFIG_URL, params['config_url']
  end

  def test_the_browser_cannot_name_the_conversation
    _, params, minted = prep({ 'message' => 'hi', 'id' => 'someone-elses-chat' })

    refute_equal 'someone-elses-chat', params['id']
    refute_nil minted
    assert_equal params['id'], @gateway.read_handle(minted)
  end

  def test_symbol_keys_are_accepted
    method, params, = prep({ message: 'hi' })

    assert_equal 'chat', method
    assert_equal 'hi', params['message']
  end

  def test_only_the_browser_methods_pass
    %w[chat_log summarize delete create_conversation].each do |method|
      assert_rejected(400) { prep({ 'method' => method, 'message' => 'hi' }) }
    end
  end

  # Keeping it off the wire is what makes a stolen key a bill, not a breach.
  def test_chat_log_is_not_reachable
    assert_rejected { prep({ 'method' => 'chat_log' }) }
  end

  def test_the_first_chat_mints_and_later_ones_reuse
    _, first, minted = prep({ 'message' => 'one' })

    assert minted
    _, second, again = prep({ 'message' => 'two', 'handle' => minted })

    assert_nil again
    assert_equal first['id'], second['id']
  end

  def test_end_needs_a_handle
    err = assert_rejected(400) { prep({ 'method' => 'end' }) }

    assert_equal 'end requires a handle', err.reason
  end

  def test_end_maps_to_the_service_method
    minted = @gateway.mint_handle
    method, params, = prep({ 'method' => 'end', 'handle' => minted })

    assert_equal 'end_conversation', method
    assert_equal({ 'id' => @gateway.read_handle(minted) }, params)
  end

  def test_an_empty_message_is_refused
    [nil, '', '   ', 5].each do |bad|
      assert_rejected { prep({ 'message' => bad }) }
    end
  end

  def test_a_bad_key_is_refused_before_anything_else
    assert_rejected(401) { @gateway.prepare({ 'message' => 'hi' }, origin: ORIGIN, key: 'nope') }
  end
end

class ChatGatewayCapsTest < Minitest::Test
  include GatewayTestHelper

  # A leaked key mints thousands of one-turn conversations; each bills.
  def test_minting_is_capped
    gw = make_gateway(max_new_conversations: 3)
    3.times { gw.prepare({ 'message' => 'hi' }, origin: nil, key: KEY) }
    err = assert_rejected(429) { gw.prepare({ 'message' => 'hi' }, origin: nil, key: KEY) }

    assert_equal 'too many new conversations', err.reason
  end

  def test_turns_are_capped_per_conversation
    gw = make_gateway(max_turns: 2)
    handle = gw.mint_handle
    2.times { gw.prepare({ 'message' => 'hi', 'handle' => handle }, origin: nil, key: KEY) }
    err = assert_rejected(429) { gw.prepare({ 'message' => 'hi', 'handle' => handle }, origin: nil, key: KEY) }

    assert_equal 'conversation turn limit reached', err.reason
  end

  def test_one_conversation_hitting_its_cap_does_not_stop_another
    gw = make_gateway(max_turns: 1)
    a = gw.mint_handle
    b = gw.mint_handle
    gw.prepare({ 'message' => 'hi', 'handle' => a }, origin: nil, key: KEY)
    gw.prepare({ 'message' => 'hi', 'handle' => b }, origin: nil, key: KEY)

    assert_rejected { gw.prepare({ 'message' => 'again', 'handle' => a }, origin: nil, key: KEY) }
  end

  # Concurrent requests share one gateway under a threaded Rack server; the cap
  # must hold across threads, not just within one.
  def test_the_mint_cap_holds_across_threads
    gw = make_gateway(max_new_conversations: 5)
    results = Array.new(20) do
      Thread.new do
        gw.prepare({ 'message' => 'hi' }, origin: nil, key: KEY)
        :ok
      rescue Rejection
        :refused
      end
    end.map(&:value)

    assert_equal 5, results.count(:ok)
  end
end

class ChatGatewayStartAndLogTest < Minitest::Test
  include GatewayTestHelper

  # A widget wants the agent to speak first, before anyone has typed.
  def test_start_mints_and_opens_with_no_message
    method, params, minted = prep({ 'method' => 'start' })

    assert_equal 'create_conversation', method
    refute_nil minted
    assert_equal({ 'id' => @gateway.read_handle(minted), 'config_url' => CONFIG_URL }, params)
  end

  # The conversation comes from inside the signed handle.
  def test_log_is_scoped_to_the_handle_not_the_body
    handle = @gateway.mint_handle
    method, params, = prep({ 'method' => 'log', 'handle' => handle, 'id' => 'someone-elses-chat' })

    assert_equal 'chat_log', method
    assert_equal({ 'id' => @gateway.read_handle(handle) }, params)
  end

  def test_log_needs_a_handle
    assert_rejected { prep({ 'method' => 'log' }) }
  end

  RAW_TRANSCRIPT = [
    { 'role' => 'system', 'content' => 'You are Sigmond. Secret instructions.' },
    { 'role' => 'user', 'content' => 'hi', 'timestamp' => 123 },
    { 'role' => 'assistant', 'content' => nil, 'tool_calls' => [{ 'id' => 'call_1' }] },
    { 'role' => 'tool', 'content' => '{"internal": "result"}' },
    { 'role' => 'assistant', 'content' => 'Hello!', 'timestamp' => 124 },
    { 'role' => 'assistant', 'content' => '   ' }
  ].freeze

  # chat_log returns the substituted SYSTEM PROMPT and the tool traffic.
  def test_the_transcript_hides_everything_but_the_dialogue
    out = Gateway.visible_messages(RAW_TRANSCRIPT)

    assert_equal [
      { 'role' => 'user', 'content' => 'hi', 'timestamp' => 123 / 1_000_000.0 },
      { 'role' => 'assistant', 'content' => 'Hello!', 'timestamp' => 124 / 1_000_000.0 }
    ], out
    blob = JSON.generate(out)

    refute_includes blob, 'Secret instructions'
    refute_includes blob, 'tool_calls'
    refute_includes blob, 'internal'
  end

  # A 1000000x unit slip here is SILENT.
  def test_the_transcript_reports_seconds_not_microseconds
    ts_us = 1_786_258_737_756_596
    out = Gateway.visible_messages([{ 'role' => 'user', 'content' => 'hi', 'timestamp' => ts_us }])

    assert_in_delta 1_786_258_737.756596, out[0]['timestamp'], 1e-6
    assert_in_delta 1_786_258_737.756596,
                    Gateway.last_activity([{ 'role' => 'user', 'content' => 'hi', 'timestamp' => ts_us }]), 1e-6
  end

  # The service's idle clock runs off updated_at, which ANY write moves.
  def test_last_activity_takes_the_newest_message_of_any_role
    msgs = [
      { 'role' => 'user', 'content' => 'first', 'timestamp' => 1_000_000 },
      { 'role' => 'assistant', 'content' => 'second', 'timestamp' => 3_000_000 },
      { 'role' => 'tool', 'content' => 'internal', 'timestamp' => 5_000_000 }
    ]

    assert_in_delta 5.0, Gateway.last_activity(msgs)
  end

  # nil, not 0 — a zero would read as 1970.
  def test_last_activity_is_nil_when_nothing_is_dated
    assert_nil Gateway.last_activity([{ 'role' => 'user', 'content' => 'hi' }])
    assert_nil Gateway.last_activity([])
    assert_nil Gateway.last_activity(nil)
    assert_nil Gateway.last_activity([{ 'role' => 'user', 'timestamp' => 'not a number' }])
  end

  def test_effective_timeout_is_always_a_number
    assert_equal 3600, @gateway.effective_timeout
    assert_equal 900, make_gateway(conversation_timeout: 900).effective_timeout
  end

  def test_the_transcript_survives_junk
    assert_empty Gateway.visible_messages([])
    assert_empty Gateway.visible_messages(nil)
    assert_empty Gateway.visible_messages(['not a dict', { 'role' => 'user' }])
  end
end

class ChatGatewayPageContextTest < Minitest::Test
  include GatewayTestHelper

  PAGE = {
    'capabilities' => { 'widget' => 'signalwire-address', 'medium' => 'chat' },
    'metadata' => { 'page' => { 'url' => 'https://shop.example.com/pricing', 'title' => 'Pricing' } }
  }.freeze

  def test_page_context_reaches_the_create_params
    method, params, = prep({ 'method' => 'start', 'user_meta_data' => PAGE })

    assert_equal 'create_conversation', method
    assert_equal 'Pricing', params['user_meta_data']['metadata']['page']['title']
  end

  # chat auto-creates when nothing was started, so the bag rides every chat.
  def test_page_context_rides_the_chat_path_too
    _, first, handle = prep({ 'method' => 'start', 'user_meta_data' => PAGE })

    assert_equal PAGE, first['user_meta_data']
    moved = { 'metadata' => { 'page' => { 'url' => 'https://shop.example.com/docs' } } }
    _, later, = prep({ 'message' => 'and now?', 'handle' => handle, 'user_meta_data' => moved })

    assert_equal moved, later['user_meta_data']
  end

  # Absent, null and empty must all mean the key simply is not there.
  def test_page_context_is_optional
    [{ 'method' => 'start' }, { 'method' => 'start', 'user_meta_data' => nil },
     { 'method' => 'start', 'user_meta_data' => {} }].each do |body|
      _, params, = prep(body)

      refute params.key?('user_meta_data')
    end
  end

  def test_page_context_must_be_an_object
    ['a string', 42, %w[a list], true].each do |bad|
      err = assert_rejected(400) { prep({ 'method' => 'start', 'user_meta_data' => bad }) }

      assert_equal 'user_meta_data must be an object', err.reason
    end
  end

  def test_page_context_is_bounded
    fat = { 'junk' => 'x' * (Gateway::MAX_USER_METADATA_BYTES + 1) }
    err = assert_rejected(413) { prep({ 'method' => 'start', 'user_meta_data' => fat }) }

    assert_equal 'user_meta_data too large', err.reason
    _, params, = prep({ 'method' => 'start', 'user_meta_data' => PAGE })

    assert_equal PAGE, params['user_meta_data']
  end

  # Measured as the reference serializes it: non-ASCII escaped to \uXXXX.
  def test_page_context_size_counts_escaped_non_ascii
    wide = { 'j' => 'é' * ((Gateway::MAX_USER_METADATA_BYTES / 6) + 1) }

    assert_rejected(413) { prep({ 'method' => 'start', 'user_meta_data' => wide }) }
  end

  def test_unserializable_page_context_is_a_clean_rejection
    err = assert_rejected(400) { prep({ 'method' => 'start', 'user_meta_data' => { 'n' => Float::NAN } }) }

    assert_equal 'user_meta_data must be JSON-serializable', err.reason
  end

  # Validating after minting would burn the new-conversation allowance.
  def test_page_context_is_rejected_before_a_conversation_is_charged
    gw = make_gateway(max_new_conversations: 1)
    assert_rejected { gw.prepare({ 'method' => 'start', 'user_meta_data' => 'nope' }, origin: nil, key: KEY) }
    _, _, minted = gw.prepare({ 'method' => 'start' }, origin: nil, key: KEY)

    refute_nil minted
  end

  # Kept nested so it cannot name a conversation or point config_url elsewhere.
  def test_page_context_cannot_displace_what_the_gateway_owns
    hostile = { 'id' => 'someone-elses-chat', 'config_url' => 'https://evil/swml' }
    _, params, minted = prep({ 'message' => 'hi', 'user_meta_data' => hostile })

    assert_equal @gateway.read_handle(minted), params['id']
    assert_equal CONFIG_URL, params['config_url']
    assert_equal hostile, params['user_meta_data']
  end
end

class ChatGatewaySizeLimitTest < Minitest::Test
  include GatewayTestHelper

  def test_a_message_over_the_limit_is_refused
    err = assert_rejected(413) { prep({ 'message' => 'x' * (Gateway::MAX_MESSAGE_BYTES + 1) }) }

    assert_equal 'message too large', err.reason
  end

  def test_a_message_at_the_limit_passes
    at_limit = 'x' * Gateway::MAX_MESSAGE_BYTES
    _, params, = prep({ 'message' => at_limit })

    assert_equal at_limit, params['message']
  end

  # Two bytes each: under the limit in characters, over it in bytes sent.
  def test_the_message_limit_counts_utf8_bytes_not_characters
    wide = 'é' * ((Gateway::MAX_MESSAGE_BYTES / 2) + 1)

    assert_operator wide.length, :<, Gateway::MAX_MESSAGE_BYTES
    assert_rejected(413) { prep({ 'message' => wide }) }
  end

  def test_an_oversized_message_mints_nothing
    gw = make_gateway(max_new_conversations: 1)
    assert_rejected { gw.prepare({ 'message' => 'x' * (Gateway::MAX_MESSAGE_BYTES + 1) }, origin: nil, key: KEY) }
    _, _, minted = gw.prepare({ 'message' => 'hi' }, origin: nil, key: KEY)

    refute_nil minted
  end

  def test_an_oversized_message_charges_no_turn
    gw = make_gateway(max_turns: 1)
    handle = gw.mint_handle
    big = { 'message' => 'x' * (Gateway::MAX_MESSAGE_BYTES + 1), 'handle' => handle }
    assert_rejected(413) { gw.prepare(big, origin: nil, key: KEY) }
    _, params, = gw.prepare({ 'message' => 'hi', 'handle' => handle }, origin: nil, key: KEY)

    assert_equal 'hi', params['message']
  end
end

class ChatGatewayHttpTest < Minitest::Test
  include GatewayTestHelper

  def test_a_full_exchange_over_http
    r = post(@gateway, { 'message' => 'hello' })

    assert_equal [200, 'hi there'], [r.status, JSON.parse(r.body).dig('result', 'response')]
    # What actually went upstream: our config_url, our conversation id, and a
    # Basic credential the browser never saw.
    sent = @service.seen.last['params']

    assert_equal [CONFIG_URL, @gateway.read_handle(r.headers['x-chat-handle'])], sent.values_at('config_url', 'id')
    refute_includes JSON.generate(sent), 'token'
  end

  def test_end_over_http
    r = post(@gateway, { 'method' => 'end', 'handle' => @gateway.mint_handle })

    assert_equal [200, { 'status' => 'ended' }], [r.status, JSON.parse(r.body)]
    assert_equal 'end_conversation', @service.seen.last['method']
  end

  def test_a_second_turn_reuses_the_handle
    handle = post(@gateway, { 'message' => 'one' }).headers['x-chat-handle']
    second = post(@gateway, { 'message' => 'two', 'handle' => handle })

    assert_nil second.headers['x-chat-handle']
    assert_equal @gateway.read_handle(handle), @service.seen.last['params']['id']
  end

  def test_http_refuses_a_bad_key
    r = post(@gateway, { 'message' => 'hi' }, { 'HTTP_AUTHORIZATION' => 'Bearer nope' })

    assert_equal 401, r.status
    assert_equal({ 'error' => 'bad key' }, JSON.parse(r.body))
  end

  def test_http_refuses_an_unlisted_origin
    r = post(@gateway, { 'message' => 'hi' },
             { 'HTTP_AUTHORIZATION' => "Bearer #{KEY}", 'HTTP_ORIGIN' => 'https://evil.test' })

    assert_equal 403, r.status
    assert_nil r.headers['access-control-allow-origin']
  end

  def test_preflight_answers_a_listed_origin
    r = http.request('OPTIONS', '/chat/', 'HTTP_ORIGIN' => ORIGIN)

    assert_equal 204, r.status
    assert_equal ORIGIN, r.headers['access-control-allow-origin']
    assert_includes r.headers['access-control-expose-headers'], 'X-Chat-Handle'
    assert_equal 'POST, OPTIONS', r.headers['access-control-allow-methods']
  end

  def test_preflight_tells_an_unlisted_origin_nothing
    r = http.request('OPTIONS', '/chat/', 'HTTP_ORIGIN' => 'https://evil.test')

    assert_equal 204, r.status
    assert_nil r.headers['access-control-allow-origin']
  end

  # A path the gateway does not own cascades, so a HandoffRouter can share the
  # prefix through Rack::Cascade.
  def test_an_unknown_path_cascades
    r = http.post('/chat/elsewhere', input: '{}')

    assert_equal 404, r.status
    assert_equal 'pass', r.headers['x-cascade']
  end

  def test_a_body_that_is_not_an_object_is_refused
    r = http.post('/chat/', HEADERS.merge(input: '[1, 2]'))

    assert_equal 400, r.status
    assert_equal({ 'error' => 'body must be an object' }, JSON.parse(r.body))
  end

  def test_invalid_json_is_a_bad_request
    r = http.post('/chat/', HEADERS.merge(input: '{nope'))

    assert_equal 400, r.status
    assert_equal({ 'error' => 'bad request' }, JSON.parse(r.body))
  end

  # The reload path end to end: start, keep the handle, read it back.
  REPLAYED = {
    'messages' => [{ 'role' => 'user', 'content' => 'hi' }, { 'role' => 'assistant', 'content' => 'hi there' }],
    'timeout' => 3600, 'last_activity' => nil
  }.freeze
  GREETING = { 'greeting' => 'Hi, I am Sigmond.', 'status' => 'created', 'timeout' => 3600 }.freeze

  def test_start_then_reload_replays_the_same_conversation
    started = post(@gateway, { 'method' => 'start' })

    assert_equal [200, GREETING], [started.status, JSON.parse(started.body)]
    handle = started.headers['x-chat-handle']
    replay = post(@gateway, { 'method' => 'log', 'handle' => handle })

    assert_equal [200, REPLAYED], [replay.status, JSON.parse(replay.body)]
    assert_equal ['chat_log', @gateway.read_handle(handle)], last_sent('id')
  end

  # The last call the stub service saw, as [method, params[key]].
  def last_sent(key)
    [@service.seen.last['method'], @service.seen.last['params'][key]]
  end

  # The number the page schedules its idle warning around must be the number the
  # service actually enforces — on the create path AND the auto-creating chat.
  def test_start_forwards_the_configured_timeout_upstream
    gw = make_gateway(allowed_origins: [ORIGIN], conversation_timeout: 900)
    started = post(gw, { 'method' => 'start' })

    assert_equal 900, JSON.parse(started.body)['timeout']
    assert_equal ['create_conversation', 900], last_sent('conversation_timeout')

    chatted = post(gw, { 'message' => 'hi', 'handle' => started.headers['x-chat-handle'] })

    assert_equal 200, chatted.status
    assert_equal ['chat', 900], last_sent('conversation_timeout')
  end

  # prepare() builds the params; the dispatch must not drop the bag on the wire.
  def test_page_context_survives_the_http_dispatch
    page = ChatGatewayPageContextTest::PAGE
    started = post(@gateway, { 'method' => 'start', 'user_meta_data' => page })

    assert_equal 200, started.status
    assert_equal ['create_conversation', page], last_sent('user_meta_data')

    chatted = post(@gateway, { 'message' => 'hi', 'handle' => started.headers['x-chat-handle'],
                               'user_meta_data' => page })

    assert_equal 200, chatted.status
    assert_equal ['chat', page], last_sent('user_meta_data')
  end

  def test_a_malformed_bag_is_a_clean_rejection_not_a_server_error
    r = post(@gateway, { 'method' => 'start', 'user_meta_data' => %w[not an object] })

    assert_equal 400, r.status
    assert_equal 'user_meta_data must be an object', JSON.parse(r.body)['error']
  end
end

class ChatGatewayHttpSizeLimitTest < Minitest::Test
  include GatewayTestHelper

  # The body isn't valid JSON, so a 413 rather than a 400 shows the size was
  # checked first.
  def test_http_refuses_an_oversized_body_before_parsing
    r = http.post('/chat/', HEADERS.merge(input: '{' * (Gateway::MAX_REQUEST_BODY_BYTES + 1)))

    assert_equal 413, r.status
    assert_equal({ 'error' => 'request too large' }, JSON.parse(r.body))
    assert_equal ORIGIN, r.headers['access-control-allow-origin']
    assert_empty @service.seen
  end

  # With no Content-Length the body is counted as it arrives.
  def test_http_refuses_an_oversized_chunked_body
    env = Rack::MockRequest.env_for('/', HEADERS.merge(method: 'POST',
                                                       input: ' ' * (Gateway::MAX_REQUEST_BODY_BYTES + 2048)))
    env.delete('CONTENT_LENGTH')
    status, _, body = @gateway.router.call(env)

    assert_equal [413, { 'error' => 'request too large' }], [status, JSON.parse(body.to_a.join)]
    assert_empty @service.seen
  end

  def test_http_refuses_an_oversized_message
    r = post(@gateway, { 'message' => 'x' * (Gateway::MAX_MESSAGE_BYTES + 1) })

    assert_equal 413, r.status
    assert_equal({ 'error' => 'message too large' }, JSON.parse(r.body))
    assert_nil r.headers['x-chat-handle']
    assert_empty @service.seen
  end

  # A full message and a full metadata bag fit together.
  def test_http_accepts_a_body_under_the_limit
    bag = { 'junk' => 'y' * (Gateway::MAX_USER_METADATA_BYTES - 20) }
    r = post(@gateway, { 'message' => 'x' * Gateway::MAX_MESSAGE_BYTES, 'user_meta_data' => bag })

    assert_equal 200, r.status
    assert_equal 'x' * Gateway::MAX_MESSAGE_BYTES, @service.seen.last['params']['message']
  end
end

# ── Streaming passthrough ─────────────────────────────────────────────────
class ChatGatewayStreamingTest < Minitest::Test
  include GatewayTestHelper

  def setup
    super
    @slow = StubChatService.new(slow: true)
    @slow_gateway = make_gateway(service: @slow)
  end

  def teardown
    super
    @slow&.stop
  end

  # A gateway that awaits the whole body would strip this padding and recreate,
  # inside the customer's own stack, the very proxy timeout the service pads to
  # survive.
  def test_the_keepalive_padding_is_relayed_not_swallowed
    r = post(@slow_gateway, { 'message' => 'hi' }, { 'HTTP_AUTHORIZATION' => "Bearer #{KEY}" })

    assert_equal 200, r.status
    assert r.body.start_with?(' '), 'padding was consumed instead of forwarded'
    assert_equal 'slow reply', JSON.parse(r.body)['result']['response']
  end

  # Chunks leave the upstream socket one at a time, and the route hands back a
  # lazily-produced body rather than a completed one.
  def test_raw_post_yields_the_body_chunk_by_chunk
    chunks = []
    @slow_gateway.instance_variable_get(:@client).raw_post('chat', { 'id' => 'c', 'message' => 'hi' }) do |resp|
      resp.read_body { |chunk| chunks << chunk }
    end

    assert_operator chunks.length, :>, 1, "upstream body arrived in one piece: #{chunks.inspect}"
    assert_equal '', chunks.first.strip, 'first chunk should be keepalive padding'
  end

  def test_the_route_streams_rather_than_collects
    env = Rack::MockRequest.env_for('/', method: 'POST', input: JSON.generate('message' => 'hi'),
                                         'HTTP_AUTHORIZATION' => "Bearer #{KEY}")
    sent_before = @slow.seen.length
    status, headers, body = @slow_gateway.router.call(env)

    assert_equal 200, status
    assert_equal 'application/json', headers['content-type']
    refute_kind_of Array, body, 'the route materialised the body instead of streaming it'
    assert_equal sent_before, @slow.seen.length, 'nothing should reach upstream until the body is iterated'
    assert_operator body.to_a.length, :>, 1
  end

  def test_raw_post_sends_one_json_rpc_call_and_returns_the_block_value
    client = @gateway.instance_variable_get(:@client)
    status = client.raw_post('chat', { 'id' => 'c', 'message' => 'hi' }, &:code)

    assert_equal '200', status
    sent = @service.seen.last

    assert_equal '2.0', sent['jsonrpc']
    assert_equal 'chat', sent['method']
    assert_equal({ 'id' => 'c', 'message' => 'hi' }, sent['params'])
    assert_match(/\Areq-\d+\z/, sent['id'])
  end

  def test_raw_post_needs_a_block
    client = @gateway.instance_variable_get(:@client)

    assert_raises(ArgumentError) { client.raw_post('chat', {}) }
  end
end

class ChatGatewayLifecycleTest < Minitest::Test
  include GatewayTestHelper

  # A client passed in belongs to the caller; one the gateway built is its own.
  def test_close_leaves_a_caller_owned_client_alone
    client = @gateway.instance_variable_get(:@client)
    closed = []
    client.define_singleton_method(:close) { closed << :closed }

    assert_nil @gateway.close
    assert_empty closed
  end

  CREDENTIALS = { 'SIGNALWIRE_PROJECT_ID' => 'p', 'SIGNALWIRE_API_TOKEN' => 't',
                  'SIGNALWIRE_SPACE' => 'example' }.freeze

  def test_close_releases_a_client_the_gateway_built
    saved = CREDENTIALS.to_h { |name, _| [name, ENV.fetch(name, nil)] }
    ENV.update(CREDENTIALS)
    gw = Gateway.new(config_url: CONFIG_URL, key: KEY)
    closed = []
    gw.instance_variable_get(:@client).define_singleton_method(:close) { closed << :closed }
    gw.close

    assert_equal [:closed], closed
  ensure
    saved.each { |name, value| value ? ENV[name] = value : ENV.delete(name) }
  end
end
