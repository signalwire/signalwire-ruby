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

class WebhookMiddlewareTest < Minitest::Test
  include Rack::Test::Methods

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

  def app
    captures = self
    SignalWire::Security::WebhookMiddleware.new(
      ->(env) { captures.send(:inner_app).call(env) },
      signing_key: SIGNING_KEY,
      trust_proxy: true,
      paths: nil,        # apply to every path
      methods: ['POST']
    )
  end

  # Compute a Scheme A hex signature for the URL the middleware is going
  # to reconstruct. The Rack::Test default host is example.org, default
  # port 80 → http scheme. We supply X-Forwarded-Proto/Host so the URL
  # the middleware sees matches the URL we sign here.
  def hex_sig(key, url, body)
    OpenSSL::HMAC.hexdigest('SHA1', key, url + body)
  end

  def test_valid_signature_passes_through_to_app
    body = '{"event":"call.state","params":{"call_id":"abc"}}'
    url  = 'https://example.org/webhook'
    sig  = hex_sig(SIGNING_KEY, url, body)

    header 'X-Forwarded-Proto', 'https'
    header 'X-Forwarded-Host',  'example.org'
    header 'X-SignalWire-Signature', sig
    header 'CONTENT_TYPE', 'application/json'

    post '/webhook', body

    assert_equal 200, last_response.status, "valid sig must pass through, got #{last_response.status}: #{last_response.body}"
    assert_equal 1, @app_calls.length, 'app must be called exactly once'
    # Raw body must be exposed to the downstream handler unchanged.
    assert_equal body, @raw_body_seen, 'middleware must stash the raw body on env for downstream readers'
  end

  def test_invalid_signature_returns_403_and_app_not_called
    body = '{"event":"x"}'
    header 'X-Forwarded-Proto', 'https'
    header 'X-Forwarded-Host',  'example.org'
    header 'X-SignalWire-Signature', 'definitely-not-the-right-signature'
    header 'CONTENT_TYPE', 'application/json'

    post '/webhook', body

    assert_equal 403, last_response.status, 'invalid sig must produce 403'
    assert_empty @app_calls, 'app must NOT be called when signature is invalid'
  end

  def test_missing_signature_header_returns_403
    body = '{"event":"x"}'
    header 'X-Forwarded-Proto', 'https'
    header 'X-Forwarded-Host',  'example.org'
    header 'CONTENT_TYPE', 'application/json'

    post '/webhook', body

    assert_equal 403, last_response.status, 'missing X-SignalWire-Signature must produce 403'
    assert_empty @app_calls
  end

  def test_twilio_signature_alias_accepted
    # X-Twilio-Signature must be honored as an alias of X-SignalWire-Signature.
    body = '{"event":"call.state"}'
    url  = 'https://example.org/webhook'
    sig  = hex_sig(SIGNING_KEY, url, body)

    header 'X-Forwarded-Proto', 'https'
    header 'X-Forwarded-Host',  'example.org'
    header 'X-Twilio-Signature', sig
    header 'CONTENT_TYPE', 'application/json'

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

  def test_paths_allowlist_skips_unmatched_paths
    # When paths: ['/webhook'] is set, requests to other paths are passed
    # through without signature validation.
    captures = self
    middleware = SignalWire::Security::WebhookMiddleware.new(
      ->(env) { captures.send(:inner_app).call(env) },
      signing_key: SIGNING_KEY,
      paths: ['/webhook']
    )

    # Use a one-shot Rack::MockRequest to avoid polluting the test instance's app.
    response = Rack::MockRequest.new(middleware).post('/other-path', input: '{"x":1}')

    assert_equal 200, response.status
    assert_equal 1, @app_calls.length
    assert_equal '/other-path', @app_calls.first[:path]
  end

  def test_form_encoded_scheme_b_passes
    # Scheme B canonical Twilio vector via the middleware.
    params = {
      'CallSid' => 'CA1234567890ABCDE',
      'Caller'  => '+14158675309',
      'Digits'  => '1234',
      'From'    => '+14158675309',
      'To'      => '+18005551212'
    }
    body = params.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join('&')
    sig  = 'RSOYDt4T1cUTdK1PDd93/VVr8B8='

    captures = self
    middleware = SignalWire::Security::WebhookMiddleware.new(
      ->(env) { captures.send(:inner_app).call(env) },
      signing_key: '12345',
      trust_proxy: true
    )

    response = Rack::MockRequest.new(middleware).post(
      '/myapp.php?foo=1&bar=2',
      input: body,
      'CONTENT_TYPE'              => 'application/x-www-form-urlencoded',
      'HTTP_X_FORWARDED_PROTO'    => 'https',
      'HTTP_X_FORWARDED_HOST'     => 'mycompany.com',
      'HTTP_X_SIGNALWIRE_SIGNATURE' => sig
    )

    assert_equal 200, response.status, "form sig should pass: got #{response.status} #{response.body}"
    assert_equal body, @raw_body_seen
  end

  def test_raw_body_rewindable_after_middleware
    # Downstream handlers that re-read rack.input must still see the body.
    body = '{"event":"x"}'
    url  = 'https://example.org/webhook'
    sig  = hex_sig(SIGNING_KEY, url, body)

    inner_read = nil
    captures = self
    inner = lambda do |env|
      inner_read = env['rack.input'].read
      captures.instance_variable_get(:@app_calls) << { path: env['PATH_INFO'] }
      [200, {}, ['']]
    end

    middleware = SignalWire::Security::WebhookMiddleware.new(
      inner,
      signing_key: SIGNING_KEY,
      trust_proxy: true
    )

    response = Rack::MockRequest.new(middleware).post(
      '/webhook',
      input: body,
      'HTTP_X_FORWARDED_PROTO'      => 'https',
      'HTTP_X_FORWARDED_HOST'       => 'example.org',
      'HTTP_X_SIGNALWIRE_SIGNATURE' => sig
    )

    assert_equal 200, response.status
    assert_equal body, inner_read,
                 'middleware must rewind rack.input so downstream can re-read'
  end
end
