# frozen_string_literal: true

# Behavioral contract #5: Serverless per-platform DISPATCH.
#
# Python (serverless_mixin.py) dispatches handle_serverless_request by platform
# — lambda, cgi, google_cloud_function, azure_function — each producing a real
# response. Before this fix the Ruby run()/_detect_run_mode only branched
# lambda + cgi; gcf and azure fell THROUGH to serve() (a blocking WEBrick
# boot), never producing a serverless response. These tests feed a synthetic
# platform event/env to each mode via the force-mode path and assert a real
# HTTP-shaped response comes back (not a fall-through to serve(), not an empty
# handler).

require 'minitest/autorun'
require 'json'
require 'stringio'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'
require_relative 'runtime_test' # pull in RuntimeEnvIsolation

class ServerlessDispatchTest < Minitest::Test
  include RuntimeEnvIsolation

  def teardown
    %w[PATH_INFO REQUEST_METHOD QUERY_STRING].each { |k| ENV.delete(k) }
    super
  end

  def build_agent
    agent = SignalWire::AgentBase.new(name: 'sless', route: '/', basic_auth: %w[u p])
    agent.set_prompt_text('Hello from serverless')
    agent.define_tool(name: 'echo', description: 'echo',
                      parameters: { 'message' => { 'type' => 'string' } }, handler: nil) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("echo: #{args['message']}")
    end
    agent
  end

  # ------------------------------------------------------------------
  # LAMBDA
  # ------------------------------------------------------------------
  def test_lambda_dispatch_returns_response_hash
    agent = build_agent
    event = { 'httpMethod' => 'GET', 'path' => '/health', 'headers' => {} }

    resp = agent.run(event: event, force_mode: 'lambda')

    assert_kind_of Hash, resp
    assert_equal 200, resp['statusCode']
    payload = JSON.parse(resp['body'])

    assert_equal 'healthy', payload['status']
  end

  # ------------------------------------------------------------------
  # CGI
  # ------------------------------------------------------------------
  def test_cgi_dispatch_writes_status_line_and_body
    agent = build_agent
    # CGI reads PATH_INFO / REQUEST_METHOD from ENV; /health needs no auth.
    ENV['PATH_INFO']      = '/health'
    ENV['REQUEST_METHOD'] = 'GET'

    out = agent.run(force_mode: 'cgi')

    assert_kind_of String, out
    assert_match(/\AStatus: 200/, out)
    body = out.split("\r\n\r\n", 2).last

    assert_equal 'healthy', JSON.parse(body)['status']
  end

  # ------------------------------------------------------------------
  # GCF (google_cloud_function) — the previously-missing handler
  # ------------------------------------------------------------------
  def test_gcf_dispatch_returns_response_hash
    agent = build_agent
    request = { 'method' => 'GET', 'path' => '/health', 'headers' => {} }

    resp = agent.run(event: request, force_mode: 'google_cloud_function')

    assert_kind_of Hash, resp
    assert_equal 200, resp['status']
    assert_equal 'healthy', JSON.parse(resp['body'])['status']
  end

  def test_gcf_dispatch_executes_swaig_function
    agent = build_agent
    body = JSON.generate('function' => 'echo', 'argument' => { 'parsed' => [{ 'message' => 'gcf' }] })
    request = {
      'method' => 'POST', 'path' => '/swaig', 'body' => body,
      'headers' => { 'Authorization' => "Basic #{['u:p'].pack('m0').chomp}", 'Content-Type' => 'application/json' }
    }

    resp = agent.run(event: request, force_mode: 'gcf')

    assert_equal 200, resp['status']
    assert_equal 'echo: gcf', JSON.parse(resp['body'])['response']
  end

  # ------------------------------------------------------------------
  # AZURE (azure_function) — the previously-missing handler
  # ------------------------------------------------------------------
  def test_azure_dispatch_returns_response_hash
    agent = build_agent
    request = { 'method' => 'GET', 'url' => 'https://app.azurewebsites.net/health', 'headers' => {} }

    resp = agent.run(event: request, force_mode: 'azure_function')

    assert_kind_of Hash, resp
    assert_equal 200, resp['status']
    assert_equal 'healthy', JSON.parse(resp['body'])['status']
  end

  def test_azure_dispatch_url_with_query_is_split
    agent = build_agent
    request = { 'method' => 'GET', 'url' => 'https://app.azurewebsites.net/health?foo=bar', 'headers' => {} }

    resp = agent.run(event: request, force_mode: 'azure')

    assert_equal 200, resp['status']
  end

  # ------------------------------------------------------------------
  # Auto-detection routes gcf/azure through the serverless handlers, NOT
  # through serve() (which would block on a WEBrick boot).
  # ------------------------------------------------------------------
  def test_detect_run_mode_recognises_gcf
    ENV['K_SERVICE'] = 'my-service'

    assert_equal 'google_cloud_function', build_agent._detect_run_mode
  end

  def test_detect_run_mode_recognises_azure
    ENV['FUNCTIONS_WORKER_RUNTIME'] = 'ruby'

    assert_equal 'azure_function', build_agent._detect_run_mode
  end

  def test_handle_serverless_request_dispatches_gcf
    agent = build_agent
    request = { 'method' => 'GET', 'path' => '/health', 'headers' => {} }

    resp = agent.handle_serverless_request(event: request, mode: 'google_cloud_function')

    assert_equal 200, resp['status']
  end
end
