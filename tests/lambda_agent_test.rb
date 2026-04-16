# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'
require_relative 'runtime_test' # pull in RuntimeEnvIsolation

# Helper that digs the default SWAIG webhook URL out of a rendered SWML
# document. Every agent-webhook test here uses this, so it's centralised
# to keep the tests focused on the URL assertions themselves.
module SwmlWebhookUrlHelper
  def default_swaig_url(agent)
    swml = agent.render_swml
    ai   = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    ai['SWAIG']['defaults']['web_hook_url']
  end
end

# ==========================================================================
# URL generation under Lambda
# ==========================================================================
class LambdaWebhookUrlTest < Minitest::Test
  include RuntimeEnvIsolation
  include SwmlWebhookUrlHelper

  def test_lambda_url_used_when_no_proxy_base_root_route
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'
    ENV['AWS_REGION']               = 'us-east-1'

    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)

    assert_includes url, 'my-func.lambda-url.us-east-1.on.aws'
    assert_includes url, '/swaig'
    # Auth credentials must still be embedded for the SignalWire platform
    # to authenticate webhook callbacks.
    assert_includes url, 'u:p@'
  end

  def test_lambda_url_used_when_no_proxy_base_non_root_route
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'
    ENV['AWS_REGION']               = 'eu-west-2'

    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/my-agent')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)

    assert_includes url, 'my-func.lambda-url.eu-west-2.on.aws'
    assert_includes url, '/my-agent/swaig',
                    'non-root route must appear before the endpoint'
  end

  def test_aws_lambda_function_url_takes_precedence_over_derived
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'ignored'
    ENV['AWS_LAMBDA_FUNCTION_URL']  = 'https://abc.lambda-url.us-west-2.on.aws'

    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)
    assert_includes url, 'abc.lambda-url.us-west-2.on.aws'
    refute_includes url, 'ignored'
  end

  def test_region_defaults_to_us_east_1_when_not_set
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'
    # AWS_REGION intentionally unset

    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)
    assert_includes url, 'my-func.lambda-url.us-east-1.on.aws'
  end

  def test_not_lambda_means_no_lambda_url
    # No Lambda env vars set; must fall back to the local server URL.
    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)
    refute_includes url, 'lambda-url'
    assert_match %r{http://u:p@}, url
  end
end

# ==========================================================================
# Regression: proxy base + non-root route + Lambda env
# ==========================================================================
#
# This is the load-bearing test for the bug called out in the task brief:
# when SWML_PROXY_URL_BASE is set (e.g. because the function is fronted
# by API Gateway or CloudFront) the agent's route MUST still be appended.
# If _base_url ever swallows the route, this test will catch it.
class LambdaProxyRouteRegressionTest < Minitest::Test
  include RuntimeEnvIsolation
  include SwmlWebhookUrlHelper

  def test_proxy_base_with_non_root_route_on_lambda_preserves_route
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'
    ENV['AWS_REGION']               = 'us-east-1'
    ENV['SWML_PROXY_URL_BASE']      = 'https://xyz.lambda-url.us-east-1.on.aws'

    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/my-agent')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)

    # The fully-qualified webhook URL must include the route before the
    # endpoint. If _base_url accidentally returns a URL with a path, or
    # _build_webhook_url short-circuits on a proxy, the route vanishes.
    assert_includes url, 'https://xyz.lambda-url.us-east-1.on.aws/my-agent/swaig',
                    "expected route '/my-agent' to appear before '/swaig', got #{url.inspect}"
    refute_includes url, 'xyz.lambda-url.us-east-1.on.aws/swaig',
                    "the proxy base must not be joined directly to '/swaig' (route dropped!)"
  end

  def test_proxy_base_without_route_still_works
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'
    ENV['SWML_PROXY_URL_BASE']      = 'https://proxy.example.com'

    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)
    assert_includes url, 'https://proxy.example.com/swaig'
  end

  def test_proxy_base_with_trailing_slash_is_normalised
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my-func'
    ENV['SWML_PROXY_URL_BASE']      = 'https://proxy.example.com/'

    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'], route: '/my-agent')
    agent.define_tool(name: 'test', description: 'test') { |_, _| }

    url = default_swaig_url(agent)
    assert_includes url, 'https://proxy.example.com/my-agent/swaig'
    refute_includes url, '//my-agent', 'trailing slash on base must not produce a double slash'
  end
end

# ==========================================================================
# Integration: LambdaHandler invoking a real agent's Rack app
# ==========================================================================
class LambdaHandlerIntegrationTest < Minitest::Test
  include RuntimeEnvIsolation

  def setup
    super
    @agent = SignalWire::AgentBase.new(
      name:       'lambda-agent',
      route:      '/',
      basic_auth: ['testuser', 'testpass']
    )
    @agent.set_prompt_text('Hello from Lambda')
    @agent.define_tool(
      name:        'echo',
      description: 'Echo back a message',
      parameters:  { 'message' => { 'type' => 'string' } }
    ) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("echo: #{args['message']}")
    end
    @handler = SignalWire::Serverless::LambdaHandler.new(@agent.rack_app)
  end

  # ------------ Function URL / API Gateway v2 payload -----------------

  def function_url_event(method:, path:, body: nil, headers: {}, query: nil)
    merged_headers = {
      'authorization' => 'Basic ' + ['testuser:testpass'].pack('m0').chomp,
      'content-type'  => 'application/json',
      'host'          => 'abc.lambda-url.us-east-1.on.aws'
    }.merge(headers)

    event = {
      'version'     => '2.0',
      'routeKey'    => '$default',
      'rawPath'     => path,
      'rawQueryString' => query.to_s,
      'headers'     => merged_headers,
      'requestContext' => {
        'http' => { 'method' => method, 'path' => path, 'protocol' => 'HTTP/1.1' },
        'stage' => '$default'
      }
    }
    if body
      event['body']            = body
      event['isBase64Encoded'] = false
    end
    event
  end

  def test_health_endpoint_does_not_require_auth
    event = function_url_event(method: 'GET', path: '/health', headers: {})
    event['headers'].delete('authorization')

    resp = @handler.call(event, nil)

    assert_equal 200, resp['statusCode']
    assert_equal 'application/json', resp['headers']['content-type']
    payload = JSON.parse(resp['body'])
    assert_equal 'healthy', payload['status']
    refute resp['isBase64Encoded'], 'plain JSON must not be base64 encoded'
  end

  def test_swml_endpoint_returns_document_in_v2_shape
    event = function_url_event(method: 'GET', path: '/')

    resp = @handler.call(event, nil)

    assert_equal 200, resp['statusCode']
    assert resp.key?('statusCode')
    assert resp.key?('headers')
    assert resp.key?('body')
    assert resp.key?('isBase64Encoded')
    payload = JSON.parse(resp['body'])
    # The SWML document carries the agent's prompt — enough to prove the
    # Rack pipeline ran end-to-end.
    assert payload.key?('sections')
    main = payload['sections']['main']
    ai_verb = main.find { |v| v.key?('ai') }
    assert ai_verb, "rendered SWML should include an 'ai' verb"
  end

  def test_swaig_dispatch_via_post
    body = JSON.generate(
      'function'  => 'echo',
      'argument'  => { 'parsed' => [{ 'message' => 'from-lambda' }] }
    )
    event = function_url_event(method: 'POST', path: '/swaig', body: body)

    resp = @handler.call(event, nil)

    assert_equal 200, resp['statusCode']
    payload = JSON.parse(resp['body'])
    assert_equal 'echo: from-lambda', payload['response']
  end

  def test_unauthorized_swml_request_returns_401
    event = function_url_event(method: 'GET', path: '/', headers: {})
    event['headers'].delete('authorization')

    resp = @handler.call(event, nil)
    assert_equal 401, resp['statusCode']
  end

  # ----------------- API Gateway v1 (REST API) payload -----------------

  def rest_event(method:, path:, body: nil)
    {
      'httpMethod' => method,
      'path'       => path,
      'headers'    => {
        'Authorization' => 'Basic ' + ['testuser:testpass'].pack('m0').chomp,
        'Content-Type'  => 'application/json',
        'Host'          => 'api.example.com'
      },
      'body'             => body,
      'isBase64Encoded'  => false
    }
  end

  def test_v1_payload_shape_returns_v1_response_shape
    event = rest_event(method: 'GET', path: '/health')

    resp = @handler.call(event, nil)
    assert_equal 200, resp['statusCode']
    # v1 responses include multiValueHeaders; v2 responses do not.
    assert resp.key?('multiValueHeaders'), 'v1 payload must produce v1 response shape'
  end

  # ----------------- Query string + base64 body ------------------------

  def test_query_string_is_forwarded
    event = function_url_event(method: 'GET', path: '/health', query: 'foo=bar&baz=quux')
    event['headers'].delete('authorization')
    resp = @handler.call(event, nil)
    # Health endpoint doesn't care about the query string; we just
    # exercise the encoding path to make sure it doesn't blow up.
    assert_equal 200, resp['statusCode']
  end

  def test_base64_encoded_body_is_decoded
    raw_body = JSON.generate(
      'function'  => 'echo',
      'argument'  => { 'parsed' => [{ 'message' => 'b64' }] }
    )
    event = function_url_event(method: 'POST', path: '/swaig', body: nil)
    require 'base64'
    event['body']            = Base64.strict_encode64(raw_body)
    event['isBase64Encoded'] = true

    resp = @handler.call(event, nil)

    assert_equal 200, resp['statusCode']
    payload = JSON.parse(resp['body'])
    assert_equal 'echo: b64', payload['response']
  end

  # ----------------- Handler factory -----------------------------------

  def test_for_factory_accepts_agent
    handler = SignalWire::Serverless::LambdaHandler.for(@agent)
    event = function_url_event(method: 'GET', path: '/health')
    event['headers'].delete('authorization')

    resp = handler.call(event, nil)
    assert_equal 200, resp['statusCode']
  end

  def test_for_factory_accepts_rack_app
    handler = SignalWire::Serverless::LambdaHandler.for(@agent.rack_app)
    event = function_url_event(method: 'GET', path: '/health')
    event['headers'].delete('authorization')

    resp = handler.call(event, nil)
    assert_equal 200, resp['statusCode']
  end

  def test_constructor_rejects_non_rack_app
    assert_raises(ArgumentError) { SignalWire::Serverless::LambdaHandler.new('not a rack app') }
  end
end
