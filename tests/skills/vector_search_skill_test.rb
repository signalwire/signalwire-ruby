# frozen_string_literal: true

require 'minitest/autorun'
require 'socket'
require 'json'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/native_vector_search'

class VectorSearchSkillDetailedTest < Minitest::Test
  def test_setup_requires_remote_url
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({})

    refute skill.setup

    skill_with_url = factory.call({ 'remote_url' => 'https://example.com/search' })

    assert skill_with_url.setup
  end

  def test_register_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search' })
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_equal 'search_knowledge', tools[0][:name]
  end

  def test_custom_tool_name
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search', 'tool_name' => 'find_docs' })
    skill.setup
    tools = skill.register_tools

    assert_equal 'find_docs', tools[0][:name]
  end

  def test_get_hints
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search' })
    skill.setup
    hints = skill.get_hints

    assert_includes hints, 'search'
    assert_includes hints, 'documentation'
  end

  def test_custom_hints
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search', 'hints' => ['custom'] })
    skill.setup
    hints = skill.get_hints

    assert_includes hints, 'custom'
  end

  def test_empty_query_returns_message
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search' })
    skill.setup
    tools = skill.register_tools
    handler = tools[0][:handler]
    result = handler.call({ 'query' => '' }, {})

    assert_includes result.response, 'provide a search query'
  end
end

# ===========================================================================
# A tiny single-request HTTP mock server bound to a FREE port (port 0). It
# captures the first request (path + body), replies with a canned JSON body,
# and shuts down. Used to prove native_vector_search makes a real remote POST.
# ===========================================================================
class SearchMockServer
  attr_reader :port, :requests

  def initialize(response_body)
    @response_body = response_body
    @requests = []
    @server = TCPServer.new('127.0.0.1', 0) # 0 => OS picks a free port
    @port = @server.addr[1]
    @thread = Thread.new { serve_one }
  end

  def base_url = "http://127.0.0.1:#{@port}"

  def stop
    @server.close unless @server.closed?
    @thread&.join(2)
  end

  private

  def serve_one
    client = @server.accept
    request_line = client.gets.to_s # e.g. "POST /search HTTP/1.1"
    method, path, = request_line.split
    headers = read_headers(client)
    body = read_body(client, headers)
    @requests << { method: method, path: path, body: body }
    write_response(client)
    client.close
  rescue IOError
    # server closed while waiting — fine for a one-shot mock
  end

  def read_headers(client)
    headers = {}
    while (line = client.gets)
      line = line.chomp
      break if line.empty?

      k, v = line.split(': ', 2)
      headers[k.downcase] = v
    end
    headers
  end

  def read_body(client, headers)
    len = headers['content-length'].to_i
    len.positive? ? client.read(len) : ''
  end

  def write_response(client)
    client.write("HTTP/1.1 200 OK\r\n")
    client.write("Content-Type: application/json\r\n")
    client.write("Content-Length: #{@response_body.bytesize}\r\n")
    client.write("Connection: close\r\n\r\n")
    client.write(@response_body)
  end
end

# ===========================================================================
# Behavioral contract #4: native_vector_search REMOTE HTTP (not a stub string).
# With remote_url set, the search tool must POST {query,...} to
# "<remote_url>/search" and format the returned [{content,score,metadata}]
# results into the FunctionResult — a real network call, not a canned string.
# ===========================================================================
class VectorSearchRemoteHttpTest < Minitest::Test
  def build_skill(base_url, extra = {})
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => base_url }.merge(extra))

    assert skill.setup, 'skill must set up in remote mode'
    skill
  end

  MOCK_RESULTS = JSON.generate(
    'results' => [
      { 'content' => 'SignalWire is a communications platform.', 'score' => 0.91, 'metadata' => { 'src' => 'docs' } },
      { 'content' => 'It supports SWML and SWAIG.', 'score' => 0.82, 'metadata' => {} }
    ]
  )

  # (1) a real POST reached "<remote_url>/search" with the query + index in body
  def assert_remote_post(req)
    refute_nil req, 'skill must make an HTTP request to the remote server'
    assert_equal 'POST', req[:method]
    assert_equal '/search', req[:path]
    sent = JSON.parse(req[:body])

    assert_equal 'what is signalwire', sent['query']
    assert_equal 'kb', sent['index_name']
  end

  # (2) the mock's results are formatted into the FunctionResult (not a
  #     hardcoded "[Would query…]" / "In production…" stub string).
  def assert_results_formatted(response)
    assert_includes response, 'SignalWire is a communications platform.'
    assert_includes response, 'It supports SWML and SWAIG.'
    refute_match(/would query|in production/i, response)
  end

  def test_search_posts_to_remote_and_formats_results
    mock = SearchMockServer.new(MOCK_RESULTS)
    begin
      handler = build_skill(mock.base_url, 'index_name' => 'kb').register_tools[0][:handler]
      result = handler.call({ 'query' => 'what is signalwire', 'count' => 2 }, {})

      assert_remote_post(mock.requests.first)
      assert_results_formatted(result.response)
    ensure
      mock.stop
    end
  end

  def test_remote_search_unavailable_is_reported
    # Point at a closed port -> connection refused -> graceful error, not crash.
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close # free the port so the connection is refused

    skill = build_skill("http://127.0.0.1:#{port}")
    handler = skill.register_tools[0][:handler]

    result = handler.call({ 'query' => 'x' }, {})

    assert_kind_of SignalWire::Swaig::FunctionResult, result
    assert_match(/unavailable|error searching/i, result.response,
                 "expected a graceful failure message, got: #{result.response.inspect}")
  end
end
