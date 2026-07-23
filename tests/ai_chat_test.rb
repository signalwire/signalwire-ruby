# frozen_string_literal: true

require 'minitest/autorun'
require 'socket'
require 'json'
require 'base64'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire/ai_chat'

# A tiny in-process HTTP server mirroring porting-sdk's mock_ai_chat responder:
# it records every JSON-RPC request (method, params, Authorization header) and
# replies with the canned success result — or, for a "__err_<code>" / a
# "__summarize_error" sentinel id, the matching error / one_of-{error} branch.
#
# Running the REAL Net::HTTP path (not a stubbed transport) proves the client's
# wire encoding, Basic-auth header, and buffered JSON parse end-to-end.
class MockAIChat
  # A recorded request the client put on the wire. :method mirrors the wire
  # method field name (as MockTest's JournalEntry does), overriding Struct#method.
  # rubocop:disable Lint/StructNewOverride
  Recorded = Struct.new(:method, :params, :authorization, keyword_init: true)
  # rubocop:enable Lint/StructNewOverride

  CANNED = {
    'create_conversation' => { 'status' => 'created', 'id' => 'conv-1', 'initial_message' => 'hello' },
    'chat' => { 'response' => 'hi there', 'user_event' => { 'event_type' => 'demo', 'n' => 1 } },
    'end_conversation' => { 'status' => 'ended', 'id' => 'conv-1' },
    'delete' => { 'status' => 'deleted', 'id' => 'conv-1' },
    'chat_log' => { 'chat_log' => [{ 'role' => 'user', 'content' => 'm' }], 'call_timeline' => [{ 't' => 1 }] },
    'summarize' => { 'summary' => 'a concise summary' }
  }.freeze

  attr_reader :requests

  def initialize
    @server = TCPServer.new('127.0.0.1', 0)
    @requests = []
    @thread = Thread.new { serve_loop }
  end

  def url
    "http://127.0.0.1:#{@server.addr[1]}/api/ai/chat"
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
    request_line = conn.gets
    return conn.close if request_line.nil?

    headers = read_headers(conn)
    body = read_body(conn, headers)
    auth = headers['authorization']
    reply(conn, envelope(body, auth))
  ensure
    conn.close
  end

  def read_headers(conn)
    headers = {}
    while (line = conn.gets) && line != "\r\n"
      k, v = line.split(':', 2)
      headers[k.strip.downcase] = v.strip if v
    end
    headers
  end

  def read_body(conn, headers)
    length = headers['content-length'].to_i
    length.positive? ? conn.read(length) : ''
  end

  def envelope(raw, auth)
    payload = JSON.parse(raw.empty? ? '{}' : raw)
    params = payload['params'] || {}
    @requests << Recorded.new(method: payload['method'], params: params, authorization: auth)
    { 'jsonrpc' => '2.0', 'id' => payload['id'] }.merge(outcome(payload['method'], params['id']))
  end

  # The JSON-RPC outcome (error vs result) for one method + conversation id.
  def outcome(method, id)
    if id.is_a?(String) && id.start_with?('__err_')
      return { 'error' => { 'code' => id.sub('__err_', '').to_i, 'message' => 'forced error' } }
    end
    if method == 'summarize' && id == '__summarize_error'
      return { 'result' => { 'error' => 'Failed to generate summary' } }
    end

    { 'result' => CANNED.fetch(method, {}) }
  end

  def reply(conn, obj)
    body = JSON.generate(obj)
    conn.write("HTTP/1.1 200 OK\r\n")
    conn.write("Content-Type: application/json\r\n")
    conn.write("Content-Length: #{body.bytesize}\r\n")
    conn.write("Connection: close\r\n\r\n")
    conn.write(body)
  end
end

# Identity keys that must never ride in the JSON-RPC params.
FORBIDDEN_IN_PARAMS = %w[project_id project token api_token space_id space].freeze

module AIChatTestHelper
  def setup
    @mock = MockAIChat.new
  end

  def teardown
    @mock&.stop
  end

  def client(**)
    SignalWire::AIChatClient.new(project: 'proj-1', token: 'tok-1', url: @mock.url, **)
  end
end

class AIChatClientConstructionTest < Minitest::Test
  def test_requires_a_project
    saved = ENV.fetch('SIGNALWIRE_PROJECT_ID', nil)
    ENV.delete('SIGNALWIRE_PROJECT_ID')
    err = assert_raises(ArgumentError) { SignalWire::AIChatClient.new(url: 'http://x') }
    assert_match(/project is required/, err.message)
  ensure
    ENV['SIGNALWIRE_PROJECT_ID'] = saved if saved
  end

  def test_builds_space_url_when_no_explicit_url
    c = SignalWire::AIChatClient.new(project: 'p', token: 't', space: 'myspace')

    assert_equal 'https://myspace.signalwire.com/api/ai/chat', c.url
  end

  def test_uses_explicit_url_verbatim
    c = SignalWire::AIChatClient.new(project: 'p', token: 't', url: 'http://local/api/ai/chat')

    assert_equal 'http://local/api/ai/chat', c.url
  end

  def test_raises_when_neither_url_nor_space_resolves
    saved = ENV.fetch('SIGNALWIRE_SPACE', nil)
    ENV.delete('SIGNALWIRE_SPACE')
    err = assert_raises(ArgumentError) { SignalWire::AIChatClient.new(project: 'p', token: 't') }
    assert_match(/No service URL/, err.message)
  ensure
    ENV['SIGNALWIRE_SPACE'] = saved if saved
  end

  def test_rails_dev_mode_boolean_does_not_override_target
    # A plain boolean RAILS_DEV_MODE is the persona switch, not a URL — the target
    # still comes from space.
    saved = ENV.fetch('RAILS_DEV_MODE', nil)
    ENV['RAILS_DEV_MODE'] = 'true'
    c = SignalWire::AIChatClient.new(project: 'p', token: 't', space: 'myspace')

    assert_equal 'https://myspace.signalwire.com/api/ai/chat', c.url
  ensure
    saved ? ENV['RAILS_DEV_MODE'] = saved : ENV.delete('RAILS_DEV_MODE')
  end

  def test_rails_dev_mode_url_overrides_target
    saved = ENV.fetch('RAILS_DEV_MODE', nil)
    ENV['RAILS_DEV_MODE'] = 'http://localhost:8080/'
    c = SignalWire::AIChatClient.new(project: 'p', token: 't', space: 'myspace')

    assert_equal 'http://localhost:8080/', c.url
  ensure
    saved ? ENV['RAILS_DEV_MODE'] = saved : ENV.delete('RAILS_DEV_MODE')
  end

  def test_inspect_redacts_token
    c = SignalWire::AIChatClient.new(project: 'p', token: 'super-secret', url: 'http://x')

    refute_match(/super-secret/, c.inspect)
    assert_match(/\[REDACTED\]/, c.inspect)
  end
end

class AIChatClientWireTest < Minitest::Test
  include AIChatTestHelper

  def test_basic_auth_username_is_project_identity_never_in_params
    client.create_conversation('conv-1', config_url: 'http://cfg', timeout: 30, reinit: true)
    req = @mock.requests.first

    assert_match(/\ABasic /, req.authorization)
    decoded = Base64.decode64(req.authorization.sub('Basic ', ''))

    assert_equal 'proj-1:tok-1', decoded
    FORBIDDEN_IN_PARAMS.each { |k| refute req.params.key?(k), "identity key #{k} leaked into params" }
  end

  def test_create_conversation_maps_timeout_and_decodes
    info = client.create_conversation('conv-1', config_url: 'http://cfg', timeout: 30, reinit: true)
    req = @mock.requests.first

    assert_equal 'create_conversation', req.method
    # timeout -> conversation_timeout on the wire; the whole param shape:
    expected_params = { 'id' => 'conv-1', 'config_url' => 'http://cfg',
                        'conversation_timeout' => 30, 'reinit' => true }
    expected_info = SignalWire::AIChat::ConversationInfo.new(
      id: 'conv-1', status: 'created', initial_message: 'hello'
    )

    assert_equal expected_params, req.params
    assert_equal expected_info, info
  end

  def test_chat_sends_role_user_by_default_and_decodes
    reply = client.chat('conv-1', 'hello', timeout: 30, reinit: true)
    req = @mock.requests.first

    assert_equal 'chat', req.method
    expected_params = { 'id' => 'conv-1', 'message' => 'hello', 'role' => 'user',
                        'conversation_timeout' => 30, 'reinit' => true }
    expected_reply = SignalWire::AIChat::ChatResponse.new(
      text: 'hi there', conversation_id: 'conv-1', user_event: { 'event_type' => 'demo', 'n' => 1 }
    )

    assert_equal expected_params, req.params
    assert_equal expected_reply, reply
  end

  def test_end_returns_true_on_status_ended
    assert_equal true, client.end('conv-1')
    assert_equal 'end_conversation', @mock.requests.first.method
  end

  def test_delete_returns_true_on_status_deleted
    assert_equal true, client.delete('conv-1')
    assert_equal 'delete', @mock.requests.first.method
  end

  def test_log_decodes_messages_and_call_timeline
    chat_log = client.log('conv-1')

    assert_equal 'chat_log', @mock.requests.first.method
    assert_equal [{ 'role' => 'user', 'content' => 'm' }], chat_log.messages
    assert_equal [{ 't' => 1 }], chat_log.call_timeline
  end

  def test_summarize_returns_summary_on_summary_branch
    assert_equal 'a concise summary', client.summarize('conv-1')
  end

  def test_summarize_passes_sampling_params_on_the_wire
    client.summarize('conv-1', summary_prompt: 'be brief', temperature: 0.2, max_tokens: 64)
    params = @mock.requests.first.params

    assert_equal 'be brief', params['summary_prompt']
    assert_in_delta 0.2, params['temperature']
    assert_equal 64, params['max_tokens']
  end
end

class AIChatSummarizeErrorBranchTest < Minitest::Test
  include AIChatTestHelper

  def test_raises_summary_error_never_returns_empty_string
    assert_raises(SignalWire::AIChat::SummaryError) { client.summarize('__summarize_error') }
  end

  def test_raised_summary_error_carries_server_message_and_nil_code
    err = assert_raises(SignalWire::AIChat::SummaryError) { client.summarize('__summarize_error') }
    assert_nil err.code
    assert_equal 'Failed to generate summary', err.server_message
  end
end

class AIChatErrorMappingTest < Minitest::Test
  include AIChatTestHelper

  MAPPED = {
    -32_001 => SignalWire::AIChat::ConversationNotFoundError,
    -32_005 => SignalWire::AIChat::RateLimitError,
    -32_006 => SignalWire::AIChat::RateLimitError,
    -32_007 => SignalWire::AIChat::ChatInProgressError,
    -32_009 => SignalWire::AIChat::AuthenticationError
  }.freeze

  def test_maps_each_code_to_its_typed_error_carrying_the_code
    MAPPED.each do |code, klass|
      err = assert_raises(klass) { client.chat("__err_#{code}", 'x') }
      assert_kind_of SignalWire::AIChat::AIChatError, err
      assert_equal code, err.code
    end
  end

  def test_maps_an_unmapped_code_to_the_base_error
    err = assert_raises(SignalWire::AIChat::AIChatError) { client.chat('__err_-32602', 'x') }
    assert_instance_of SignalWire::AIChat::AIChatError, err
    assert_equal(-32_602, err.code)
  end

  def test_ai_chat_error_is_part_of_the_signalwire_error_family
    err = assert_raises(SignalWire::AIChat::ConversationNotFoundError) { client.chat('__err_-32001', 'x') }
    assert_kind_of SignalWire::Error, err
  end
end
