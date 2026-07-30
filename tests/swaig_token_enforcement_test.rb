# frozen_string_literal: true

require 'minitest/autorun'
require 'base64'
require 'json'
require 'rack'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# SWAIG `secure` enforcement — the transport-agnostic token contract.
#
# A tool registered with `secure: true` (define_tool's default) REQUIRES a valid
# per-call `__token`. Absent, forged, or unvalidatable => REFUSE. This holds on
# EVERY transport, not just HTTP:
#
#   valid token   -> handler RUNS,       not refused, 200
#   forged token  -> handler does NOT run, REFUSED,   200 + FunctionResult body
#   absent token  -> handler does NOT run, REFUSED    (fail-CLOSED)
#   call_id absent-> REFUSED (a token can only be validated against a call_id,
#                    so a missing one counts as unvalidated, never a bypass)
#   insecure tool -> RUNS ungated in ALL of the above
#
# The refusal is a 200 + FunctionResult body, NOT an HTTP error status: the
# engine (mod_openai) has no handling for a SWAIG refusal status, so the tool
# reports it cannot execute and the model relays it.
#
# WHERE THE CREDENTIAL RIDES: the token rides the QUERY STRING (`__token`), the
# call_id rides the POST BODY (`call_id`). That split is identical on both
# transports -- ruby's serverless adapters translate the invocation event into a
# Rack env, so `queryStringParameters` becomes `QUERY_STRING` and the same
# `swaig_pre_dispatch` hook runs.

# The fixture agent plus one driver per transport. Both drivers take the SAME
# (function, token, call_id) triple and return the same [status, parsed-body]
# pair, so every case below runs identically on HTTP and on serverless — a green
# HTTP suite proving nothing about serverless is exactly the hole this closes.
module SwaigTokenTransports
  USER = 'user'
  PASSWORD = 'pass'
  CALL_ID = 'call-token-enforcement'
  RAN = 'handler ran'
  REFUSAL_MARK = 'security token'

  def build_agent
    agent = SignalWire::AgentBase.new(name: 'tok', route: '/', basic_auth: [USER, PASSWORD])
    agent.define_tool(name: 'sec_tool', description: 'secure', parameters: {}, handler: nil) do |_a, _r|
      SignalWire::Swaig::FunctionResult.new(RAN)
    end
    agent.define_tool(name: 'open_tool', description: 'insecure', parameters: {},
                      secure: false, handler: nil) do |_a, _r|
      SignalWire::Swaig::FunctionResult.new(RAN)
    end
    agent
  end

  def basic_auth
    "Basic #{Base64.strict_encode64("#{USER}:#{PASSWORD}")}"
  end

  def swaig_body(func, call_id: CALL_ID)
    body = { 'function' => func, 'argument' => { 'parsed' => [{}] } }
    body['call_id'] = call_id if call_id
    JSON.generate(body)
  end

  # --- transport drivers ------------------------------------------------

  # Rack env keys that do not vary between cases.
  STATIC_ENV = {
    'REQUEST_METHOD' => 'POST', 'PATH_INFO' => '/swaig', 'SCRIPT_NAME' => '',
    'SERVER_NAME' => 'localhost', 'SERVER_PORT' => '3000',
    'SERVER_PROTOCOL' => 'HTTP/1.1', 'rack.url_scheme' => 'http',
    'CONTENT_TYPE' => 'application/json'
  }.freeze

  # HTTP: drive the served Rack app directly (the path a real POST /swaig takes).
  def http_call(agent, func, token: nil, call_id: CALL_ID)
    body = swaig_body(func, call_id: call_id)
    env = STATIC_ENV.merge(
      'QUERY_STRING' => token ? "__token=#{Rack::Utils.escape(token)}" : '',
      'CONTENT_LENGTH' => body.bytesize.to_s, 'HTTP_AUTHORIZATION' => basic_auth,
      'rack.input' => StringIO.new(body), 'rack.errors' => $stderr
    )
    status, _headers, out = agent.rack_app.call(env)
    [status, JSON.parse(Array(out).join)]
  end

  # Serverless (lambda): drive the real lambda adapter, token in the parsed
  # queryStringParameters map exactly as API Gateway delivers it.
  def lambda_call(agent, func, token: nil, call_id: CALL_ID)
    event = {
      'version' => '2.0', 'rawPath' => '/swaig',
      'headers' => { 'authorization' => basic_auth, 'content-type' => 'application/json' },
      'requestContext' => { 'http' => { 'method' => 'POST' } },
      'body' => swaig_body(func, call_id: call_id)
    }
    event['queryStringParameters'] = { '__token' => token } if token
    resp = agent.handle_serverless_request(event: event, mode: 'lambda')
    [resp['statusCode'], JSON.parse(resp['body'])]
  end

  TRANSPORTS = { 'http' => :http_call, 'lambda' => :lambda_call }.freeze

  def each_transport(&)
    TRANSPORTS.each(&)
  end
end

class SwaigTokenEnforcementTest < Minitest::Test
  include SwaigTokenTransports

  def assert_ran(status, body, transport, why)
    assert_equal 200, status, "#{transport}: #{why} — must be 200"
    assert_equal RAN, body['response'], "#{transport}: #{why} — the handler MUST have run"
  end

  def assert_refused(status, body, transport, why)
    assert_equal 200, status,
                 "#{transport}: #{why} — a SWAIG refusal is a 200 + FunctionResult body, not an HTTP error"
    refute_equal RAN, body['response'], "#{transport}: #{why} — the handler MUST NOT have run"
    assert_includes body['response'].to_s, REFUSAL_MARK,
                    "#{transport}: #{why} — the refusal must be the security-token FunctionResult"
  end

  # --- secure tool: the four token cases, per transport -----------------

  def test_secure_tool_valid_token_runs
    each_transport do |name, driver|
      agent = build_agent
      token = agent.create_tool_token('sec_tool', CALL_ID)
      status, body = send(driver, agent, 'sec_tool', token: token)

      assert_ran(status, body, name, 'valid token')
    end
  end

  def test_secure_tool_forged_token_refused
    each_transport do |name, driver|
      agent = build_agent
      status, body = send(driver, agent, 'sec_tool', token: 'not-a-real-token')

      assert_refused(status, body, name, 'forged token')
    end
  end

  def test_secure_tool_absent_token_refused
    each_transport do |name, driver|
      agent = build_agent
      status, body = send(driver, agent, 'sec_tool', token: nil)

      assert_refused(status, body, name, 'absent token (must fail CLOSED)')
    end
  end

  def test_secure_tool_absent_call_id_refused
    each_transport do |name, driver|
      agent = build_agent
      token = agent.create_tool_token('sec_tool', CALL_ID)
      status, body = send(driver, agent, 'sec_tool', token: token, call_id: nil)

      assert_refused(status, body, name, 'valid token but NO call_id')
    end
  end

  # A token minted for a DIFFERENT call must not unlock this call.
  def test_secure_tool_token_for_other_call_refused
    each_transport do |name, driver|
      agent = build_agent
      token = agent.create_tool_token('sec_tool', 'some-other-call')
      status, body = send(driver, agent, 'sec_tool', token: token)

      assert_refused(status, body, name, "another call's token")
    end
  end

  # A token minted for a DIFFERENT function must not unlock this function.
  def test_secure_tool_token_for_other_function_refused
    each_transport do |name, driver|
      agent = build_agent
      token = agent.create_tool_token('open_tool', CALL_ID)
      status, body = send(driver, agent, 'sec_tool', token: token)

      assert_refused(status, body, name, "another function's token")
    end
  end

  # --- insecure tool: runs ungated in every case ------------------------

  INSECURE_CASES = {
    'valid token' => :valid, 'forged token' => :forged,
    'absent token' => :absent, 'no call_id' => :no_call_id
  }.freeze

  def test_insecure_tool_runs_ungated
    each_transport do |name, driver|
      INSECURE_CASES.each { |why, kind| assert_insecure_runs(name, driver, why, kind) }
    end
  end

  def assert_insecure_runs(name, driver, why, kind)
    agent = build_agent
    token, call_id = insecure_case_args(agent, kind)
    status, body = send(driver, agent, 'open_tool', token: token, call_id: call_id)

    assert_ran(status, body, name, "insecure tool, #{why}")
  end

  def insecure_case_args(agent, kind)
    case kind
    when :valid      then [agent.create_tool_token('open_tool', CALL_ID), CALL_ID]
    when :forged     then ['not-a-real-token', CALL_ID]
    when :absent     then [nil, CALL_ID]
    when :no_call_id then [nil, nil]
    end
  end
end
