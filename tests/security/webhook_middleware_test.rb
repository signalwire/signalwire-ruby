# frozen_string_literal: true

# Rack-level integration tests for SignalWire::Security::WebhookMiddleware.
#
# Drives a real Rack app through Rack::Test (which is the canonical Ruby
# test driver for HTTP middleware — no mocking the transport).

require 'minitest/autorun'
require 'rack/test'
require 'json'
require 'cgi'

require_relative '../../lib/signalwire/security/webhook_validator'
require_relative '../../lib/signalwire/security/webhook_middleware'

# Shared fixtures for the WebhookMiddleware test classes: the capturing inner
# app, the middleware factory, and the signing helper.
module WebhookMiddlewareHelpers
  SIGNING_KEY = 'PSKtest1234567890abcdef'

  def setup
    # Reset state captured by the inner app for each test.
    @app_calls = []
    @raw_body_seen = nil
  end

  # The inner "real" app — captures whether it was invoked, with what raw
  # body, and what env keys it observed. Returns 200 OK so the test can
  # distinguish "validator allowed through" from "validator blocked".
  def inner_app
    captures = self
    lambda do |env|
      captures.instance_variable_set(:@raw_body_seen, env['signalwire.raw_body'])
      captures.instance_variable_get(:@app_calls) << {
        path: env['PATH_INFO'],
        method: env['REQUEST_METHOD'],
        raw_body: env['signalwire.raw_body']
      }
      [200, { 'content-type' => 'application/json' }, ['{"ok":true}']]
    end
  end

  # Wrap {#inner_app} in a WebhookMiddleware with the given options.
  def build_middleware(**)
    captures = self
    SignalWire::Security::WebhookMiddleware.new(
      ->(env) { captures.send(:inner_app).call(env) }, **
    )
  end

  # Compute a Scheme A hex signature for the URL the middleware reconstructs.
  def hex_sig(key, url, body)
    OpenSSL::HMAC.hexdigest('SHA1', key, url + body)
  end
end

# Rack::Test-driven cases (the canonical in-process HTTP driver).
class WebhookMiddlewareTest < Minitest::Test
  include Rack::Test::Methods
  include WebhookMiddlewareHelpers

  def app
    build_middleware(signing_key: SIGNING_KEY, trust_proxy: true, paths: nil, methods: ['POST'])
  end

  # Set the proxy + JSON content-type headers (no signature).
  def proxy_headers
    header 'X-Forwarded-Proto', 'https'
    header 'X-Forwarded-Host',  'example.org'
    header 'CONTENT_TYPE', 'application/json'
  end

  # As {#proxy_headers}, plus the given signature under the named header
  # (defaults to the canonical X-SignalWire-Signature).
  def signed_headers(sig, sig_header: 'X-SignalWire-Signature')
    proxy_headers
    header sig_header, sig
  end

  def test_valid_signature_passes_through_to_app
    body = '{"event":"call.state","params":{"call_id":"abc"}}'
    url  = 'https://example.org/webhook'
    signed_headers(hex_sig(SIGNING_KEY, url, body))

    post '/webhook', body

    assert_equal 200, last_response.status,
                 "valid sig must pass through, got #{last_response.status}: #{last_response.body}"
    assert_equal 1, @app_calls.length, 'app must be called exactly once'
    # Raw body must be exposed to the downstream handler unchanged.
    assert_equal body, @raw_body_seen, 'middleware must stash the raw body on env for downstream readers'
  end

  def test_invalid_signature_returns_403_and_app_not_called
    body = '{"event":"x"}'
    signed_headers('definitely-not-the-right-signature')

    post '/webhook', body

    assert_equal 403, last_response.status, 'invalid sig must produce 403'
    assert_empty @app_calls, 'app must NOT be called when signature is invalid'
  end

  def test_missing_signature_header_returns403
    body = '{"event":"x"}'
    proxy_headers

    post '/webhook', body

    assert_equal 403, last_response.status, 'missing X-SignalWire-Signature must produce 403'
    assert_empty @app_calls
  end

  def test_twilio_signature_alias_accepted
    # X-Twilio-Signature must be honored as an alias of X-SignalWire-Signature.
    body = '{"event":"call.state"}'
    url  = 'https://example.org/webhook'
    signed_headers(hex_sig(SIGNING_KEY, url, body), sig_header: 'X-Twilio-Signature')

    post '/webhook', body

    assert_equal 200, last_response.status
    assert_equal 1, @app_calls.length
  end

  def test_get_request_passes_through_unchecked
    # Middleware default is methods: ['POST'] only — GETs must not be
    # blocked even if no signature header is present.
    get '/health'

    assert_equal 200, last_response.status
    assert_equal 1, @app_calls.length
  end

  def test_signing_key_required_at_construction
    assert_raises(ArgumentError) do
      SignalWire::Security::WebhookMiddleware.new(->(_e) { [200, {}, []] }, signing_key: nil)
    end
    assert_raises(ArgumentError) do
      SignalWire::Security::WebhookMiddleware.new(->(_e) { [200, {}, []] }, signing_key: '')
    end
  end

  def test_swml_proxy_url_base_used_for_url_reconstruction
    # When SWML_PROXY_URL_BASE is set, the middleware must use it as the
    # signing URL base — that's the only way agents behind ngrok/proxies
    # can match the URL the platform actually POSTed to.
    proxy_base = 'https://my-public.ngrok.io'
    body = '{"event":"call.state"}'
    sig  = hex_sig(SIGNING_KEY, "#{proxy_base}/webhook", body)

    ENV['SWML_PROXY_URL_BASE'] = proxy_base

    header 'X-SignalWire-Signature', sig
    header 'CONTENT_TYPE', 'application/json'

    post '/webhook', body

    assert_equal 200, last_response.status, 'must use SWML_PROXY_URL_BASE as URL prefix when set'
  ensure
    ENV.delete('SWML_PROXY_URL_BASE')
  end
end

# Cases driven by one-shot Rack::MockRequest (no shared Rack::Test app).
class WebhookMiddlewareMockRequestTest < Minitest::Test
  include WebhookMiddlewareHelpers

  # One-shot Rack::MockRequest POST. `env` carries CONTENT_TYPE / HTTP_* keys.
  def mock_post(middleware, path, input, **env)
    Rack::MockRequest.new(middleware).post(path, input: input, **env)
  end

  # X-Forwarded-Proto/Host + signature env keys for Rack::MockRequest, merged
  # with any extra CGI env (e.g. CONTENT_TYPE). `host` defaults to example.org.
  def forwarded_env(sig, host: 'example.org', **extra)
    {
      'HTTP_X_FORWARDED_PROTO' => 'https',
      'HTTP_X_FORWARDED_HOST' => host,
      'HTTP_X_SIGNALWIRE_SIGNATURE' => sig
    }.merge(extra)
  end

  def test_paths_allowlist_skips_unmatched_paths
    # When paths: ['/webhook'] is set, requests to other paths are passed
    # through without signature validation.
    middleware = build_middleware(signing_key: SIGNING_KEY, paths: ['/webhook'])
    response = mock_post(middleware, '/other-path', '{"x":1}')

    assert_equal 200, response.status
    assert_equal 1, @app_calls.length
    assert_equal '/other-path', @app_calls.first[:path]
  end

  # Canonical Scheme B Twilio form-encoded vector (params + precomputed sig).
  def scheme_b_form_params
    {
      'CallSid' => 'CA1234567890ABCDE', 'Caller' => '+14158675309', 'Digits' => '1234',
      'From' => '+14158675309', 'To' => '+18005551212'
    }
  end

  def test_form_encoded_scheme_b_passes
    body = scheme_b_form_params.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join('&')
    middleware = build_middleware(signing_key: '12345', trust_proxy: true)
    ct = { 'CONTENT_TYPE' => 'application/x-www-form-urlencoded' }
    env = forwarded_env('RSOYDt4T1cUTdK1PDd93/VVr8B8=', host: 'mycompany.com', **ct)
    response = mock_post(middleware, '/myapp.php?foo=1&bar=2', body, **env)

    assert_equal 200, response.status, "form sig should pass: got #{response.status} #{response.body}"
    assert_equal body, @raw_body_seen
  end

  # A rack app that records what it re-reads from rack.input. Returns
  # [app, read_capture] where read_capture is a single-element array whose
  # [0] holds the bytes read once the app runs.
  def rack_input_reader
    read_capture = []
    captures = self
    app = lambda do |env|
      read_capture[0] = env['rack.input'].read
      captures.instance_variable_get(:@app_calls) << { path: env['PATH_INFO'] }
      [200, {}, ['']]
    end
    [app, read_capture]
  end

  def test_raw_body_rewindable_after_middleware
    # Downstream handlers that re-read rack.input must still see the body.
    body = '{"event":"x"}'
    sig  = hex_sig(SIGNING_KEY, 'https://example.org/webhook', body)

    inner, read_capture = rack_input_reader
    middleware = SignalWire::Security::WebhookMiddleware.new(inner, signing_key: SIGNING_KEY, trust_proxy: true)
    response = mock_post(middleware, '/webhook', body, **forwarded_env(sig))

    assert_equal 200, response.status
    assert_equal body, read_capture[0],
                 'middleware must rewind rack.input so downstream can re-read'
  end
end

# Direct tests for the framework-free decomposed validation core
# (WebhookMiddleware.validate) — the cross-port contract from
# porting-sdk/webhooks.md decomposed at the HTTP boundary:
#   validate(method, url, headers, body, signing_key:)
#     -> nil (pass) | [status, headers, body] (reject triple)
# This is the same decision the Rack #call wrapper makes, exercised without
# constructing a middleware / Rack env.
class WebhookMiddlewareValidateCoreTest < Minitest::Test
  SIGNING_KEY = 'PSKtest1234567890abcdef'
  URL = 'https://example.org/webhook'
  BODY = '{"event":"call.state","params":{"call_id":"abc"}}'

  def run_validate(headers, body: BODY, key: SIGNING_KEY, url: URL)
    SignalWire::Security::WebhookMiddleware.validate('POST', url, headers, body, signing_key: key)
  end

  def hex_sig(key = SIGNING_KEY, url = URL, body = BODY)
    OpenSSL::HMAC.hexdigest('SHA1', key, url + body)
  end

  def test_valid_signature_returns_nil_pass
    result = run_validate({ 'X-SignalWire-Signature' => hex_sig })

    assert_nil result, 'a valid signature must return nil (pass) from the decomposed core'
  end

  def test_bad_signature_returns_403_triple
    status, headers, resp_body = run_validate({ 'X-SignalWire-Signature' => 'not-the-right-signature' })

    assert_equal 403, status, 'a bad signature must return a 403 reject triple'
    assert_instance_of Hash, headers
    assert_instance_of Array, resp_body
    assert_equal [''], resp_body, 'reject body must carry no detail (never leak which branch tripped)'
  end

  def test_missing_signature_header_returns_403_triple
    status, = run_validate({})

    assert_equal 403, status, 'a missing signature header must return a 403 reject triple (never raise)'
  end

  def test_twilio_signature_alias_honored
    # X-Twilio-Signature is accepted as a legacy cXML/Compatibility alias of
    # X-SignalWire-Signature (webhooks.md "The Header").
    result = run_validate({ 'X-Twilio-Signature' => hex_sig })

    assert_nil result, 'the X-Twilio-Signature alias must be honored (pass -> nil)'
  end

  def test_header_lookup_is_case_insensitive
    # HTTP header names are case-insensitive; a lower-cased header must still be found.
    result = run_validate({ 'x-signalwire-signature' => hex_sig })

    assert_nil result, 'signature header lookup must be case-insensitive'
  end

  def test_missing_signing_key_raises
    assert_raises(ArgumentError) do
      SignalWire::Security::WebhookMiddleware.validate('POST', URL, { 'X-SignalWire-Signature' => hex_sig }, BODY,
                                                       signing_key: nil)
    end
  end
end
