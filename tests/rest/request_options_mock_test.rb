# frozen_string_literal: true

# RequestOptions envelope — behavioral contract over the real mock (plan 4.2).
# Translated from signalwire-python/tests/unit/rest/test_request_options.py.
#
# These drive the real HttpClient through the real net/http transport into the
# shared mock_signalwire and assert on the recorded journal — the same journal
# the REST-COVERAGE gate reads. Retry / timeout are wire-observable: the mock
# sees N attempts, so the contract is proven over the real mock, NOT a stubbed
# transport.
#
# Contract pinned here (the oracle):
# - retries: a retryable failure is retried up to +retries+ extra times; the
#   mock sees +retries + 1+ attempts; the final success is returned.
# - idempotency asymmetry: GET/PUT/DELETE retry on the full retry_on_status set;
#   POST/PATCH retry only on 429/503 (throttles), never 500/502/504.
# - timeout: a server-side delay exceeding the timeout raises the transport
#   error family.
# - abort_signal: set before a request raises the transport error family.
# - per-request options shallow-override the client default.

require 'minitest/autorun'
require_relative 'mock_test'
require_relative '../../lib/signalwire/rest/request_options'

class RequestOptionsMockTest < Minitest::Test
  # Parallelize: per-client unique-project + auth-scoped harness isolates each test.
  parallelize_me!

  ADDRESSES_PATH = '/api/fabric/addresses'
  ADDRESSES_ENDPOINT_ID = 'fabric.list_fabric_addresses'
  CREATE_ADDRESS_PATH = '/api/relay/rest/addresses'
  CREATE_ADDRESS_ENDPOINT_ID = 'relay-rest.create_address'

  def setup
    h = MockTest.client
    @client  = h[:client]
    @http    = @client.http
    @mock    = h[:mock]
    @project = h[:project]
  end

  # ---- retry contract: a retryable failure is retried; the mock sees every attempt

  def test_get_retries_503_then_succeeds
    # Arm a single 503; the default synthesized 200 follows it. With retries=1
    # the client retries the 503 into the 200 => 2 attempts.
    @mock.push_scenario(ADDRESSES_ENDPOINT_ID, status: 503, response: { 'errors' => [{ 'code' => 'X' }] })
    result = @http.get(ADDRESSES_PATH, nil,
                       request_options: SignalWire::REST::RequestOptions.new(retries: 1, retry_backoff: 0))

    refute_nil result
    assert_equal 2, address_gets.length, 'expected 2 attempts (503 then 200)'
  end

  def test_no_retries_by_default_raises_on_first_failure
    # Default retries=0: the first non-2xx raises immediately (the original
    # no-retry contract remains the default; retries are opt-in).
    @mock.push_scenario(ADDRESSES_ENDPOINT_ID, status: 503, response: { 'errors' => [{ 'code' => 'X' }] })
    err = assert_raises(SignalWire::REST::SignalWireRestError) do
      @http.get(ADDRESSES_PATH)
    end
    assert_equal 503, err.status_code
    assert_equal 1, address_gets.length, 'default must not retry'
  end

  def test_retries_exhausted_raises_last_error
    # Two 503s + retries=1 => attempts = 2, both 503 => raise the 503.
    @mock.push_scenario(ADDRESSES_ENDPOINT_ID, status: 503, response: { 'errors' => [{ 'code' => 'X' }] })
    @mock.push_scenario(ADDRESSES_ENDPOINT_ID, status: 503, response: { 'errors' => [{ 'code' => 'X' }] })
    err = assert_raises(SignalWire::REST::SignalWireRestError) do
      @http.get(ADDRESSES_PATH,
                request_options: SignalWire::REST::RequestOptions.new(retries: 1, retry_backoff: 0))
    end
    assert_equal 503, err.status_code
    assert_equal 2, address_gets.length, 'retries=1 => exactly 2 attempts'
  end

  # ---- idempotency asymmetry: POST/PATCH do not blindly retry 500/502/504

  def test_post_does_not_retry500
    # A real POST route; 500 is NOT retryable for a non-idempotent method even
    # with retries armed => exactly one attempt, raise the 500.
    @mock.push_scenario(CREATE_ADDRESS_ENDPOINT_ID, status: 500, response: { 'error' => 'x' })
    err = assert_raises(SignalWire::REST::SignalWireRestError) do
      @http.post(CREATE_ADDRESS_PATH, { 'label' => 'x' },
                 request_options: SignalWire::REST::RequestOptions.new(retries: 2, retry_backoff: 0))
    end
    assert_equal 500, err.status_code
    assert_equal 1, create_posts.length, 'POST must not retry a 500 (side-effect safety)'
  end

  def test_post_does_retry503
    # 503 (throttle, carries Retry-After semantics) IS retryable even for a
    # non-idempotent method => the 503 retries into the default 200/201.
    @mock.push_scenario(CREATE_ADDRESS_ENDPOINT_ID, status: 503, response: { 'error' => 'x' })
    @http.post(CREATE_ADDRESS_PATH, { 'label' => 'x' },
               request_options: SignalWire::REST::RequestOptions.new(retries: 1, retry_backoff: 0))

    assert_equal 2, create_posts.length, 'POST retries a 503 throttle (safe): 503 then 200'
  end

  # ---- timeout: a server-side delay exceeding the timeout raises the transport error

  def test_slow_response_times_out
    # Arm a 200 delayed 400ms; a 100ms timeout must fire => transport error.
    arm_delayed(ADDRESSES_ENDPOINT_ID, status: 200, response: delayed_ok_body, delay_ms: 400)
    assert_raises(SignalWire::REST::SignalWireRestTransportError) do
      @http.get(ADDRESSES_PATH, nil,
                request_options: SignalWire::REST::RequestOptions.new(timeout: 0.1))
    end
  end

  # ---- abort_signal: a set signal raises before the request goes out

  def test_preset_abort_raises_transport_error
    signal = SignalWire::REST::AbortSignal.new.set!
    assert_raises(SignalWire::REST::SignalWireRestTransportError) do
      @http.get(ADDRESSES_PATH, nil,
                request_options: SignalWire::REST::RequestOptions.new(abort_signal: signal))
    end
    # Nothing reached the mock — cancelled before the send.
    assert_empty address_gets, 'aborted request must not reach the server'
  end

  # ---- per-request override: per-request options shallow-override the client default

  def test_per_request_retries_override_client_default
    # Client default = no retries; per-request opts in to 1 retry.
    client = SignalWire::REST::RestClient.new(
      project: @project, token: MockTest::REST_TOKEN, base_url: @mock.url,
      request_options: SignalWire::REST::RequestOptions.new(retries: 0)
    )
    @mock.push_scenario(ADDRESSES_ENDPOINT_ID, status: 503, response: { 'errors' => [{ 'code' => 'X' }] })
    result = client.http.get(ADDRESSES_PATH, nil,
                             request_options: SignalWire::REST::RequestOptions.new(retries: 1, retry_backoff: 0))

    refute_nil result
    assert_equal 2, address_gets.length, 'per-request retries override the client default'
  end

  private

  def delayed_ok_body
    { 'data' => [], 'links' => {} }
  end

  # A delayed scenario needs delay_ms, which the harness push_scenario doesn't
  # expose; arm it directly against the session-scoped scenario store.
  def arm_delayed(endpoint_id, status:, response:, delay_ms:)
    payload = JSON.generate('status' => status, 'response' => response, 'delay_ms' => delay_ms)
    q = "?session_id=#{URI.encode_www_form_component(@mock.auth_header)}"
    uri = URI("#{@mock.url}/__mock__/scenarios/#{endpoint_id}#{q}")
    Net::HTTP.start(uri.hostname, uri.port) do |http|
      req = Net::HTTP::Post.new(uri.request_uri)
      req['Content-Type'] = 'application/json'
      req.body = payload
      http.request(req)
    end
  end

  def address_gets
    @mock.journal.select { |e| e.path == ADDRESSES_PATH && e.method == 'GET' }
  end

  def create_posts
    @mock.journal.select { |e| e.path == CREATE_ADDRESS_PATH && e.method == 'POST' }
  end
end
