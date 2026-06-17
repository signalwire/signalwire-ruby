# frozen_string_literal: true

# AgentBase integration tests for webhook signature validation.
#
# Drives a real AgentBase rack app through Rack::Test:
# - When `signing_key:` is set, POST `/`, `/swaig`, and `/post_prompt` MUST
#   reject unsigned requests with 403.
# - When the signature is valid, the agent's normal handlers run.
# - When `signing_key:` is unset, no validator is mounted and POSTs are
#   handled with basic-auth only (existing AgentBase behaviour).

require 'minitest/autorun'
require 'rack/test'
require 'json'
require 'openssl'
require 'cgi'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../../lib/signalwire'

module AgentSigningKeyHelpers
  module_function

  def hex_sig(key, url, body)
    OpenSSL::HMAC.hexdigest('SHA1', key, url + body)
  end

  def basic_auth_header(user, pass)
    'Basic ' + ["#{user}:#{pass}"].pack('m0')
  end
end

# ---------------------------------------------------------------------------
# Constructor / option plumbing
# ---------------------------------------------------------------------------

class AgentSigningKeyConstructionTest < Minitest::Test
  def test_signing_key_explicit_constructor_wins
    agent = SignalWire::AgentBase.new(
      basic_auth: %w[u p],
      signing_key: 'PSK-explicit',
      suppress_logs: true
    )

    assert_equal 'PSK-explicit', agent.signing_key
  end

  def test_signing_key_falls_back_to_env
    ENV['SIGNALWIRE_SIGNING_KEY'] = 'PSK-from-env'
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p], suppress_logs: true)

    assert_equal 'PSK-from-env', agent.signing_key
  ensure
    ENV.delete('SIGNALWIRE_SIGNING_KEY')
  end

  def test_explicit_constructor_overrides_env
    ENV['SIGNALWIRE_SIGNING_KEY'] = 'PSK-from-env'
    agent = SignalWire::AgentBase.new(
      basic_auth: %w[u p],
      signing_key: 'PSK-explicit',
      suppress_logs: true
    )

    assert_equal 'PSK-explicit', agent.signing_key
  ensure
    ENV.delete('SIGNALWIRE_SIGNING_KEY')
  end

  def test_no_signing_key_when_neither_set
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p], suppress_logs: true)

    assert_nil agent.signing_key
  end
end

# ---------------------------------------------------------------------------
# Auto-mount on POST / and /post_prompt — 403 on bad sig, 200 on good
# ---------------------------------------------------------------------------

class AgentWebhookSignatureRouteEnforcementTest < Minitest::Test
  include Rack::Test::Methods

  SIGNING_KEY = 'PSKtest1234567890abcdef'

  def app
    @agent ||= begin
      a = SignalWire::AgentBase.new(
        basic_auth: %w[u p],
        signing_key: SIGNING_KEY,
        trust_proxy_for_signature: true,
        suppress_logs: true
      )
      a.set_prompt_text('Hello')
      a
    end
    @agent.rack_app
  end

  def signed_post(path, body, content_type: 'application/json')
    url = "https://signed.example.org#{path}"
    sig = AgentSigningKeyHelpers.hex_sig(SIGNING_KEY, url, body)

    header 'X-Forwarded-Proto', 'https'
    header 'X-Forwarded-Host',  'signed.example.org'
    header 'X-SignalWire-Signature', sig
    header 'Authorization', AgentSigningKeyHelpers.basic_auth_header('u', 'p')
    header 'CONTENT_TYPE', content_type

    post path, body
  end

  def unsigned_post(path, body)
    header 'Authorization', AgentSigningKeyHelpers.basic_auth_header('u', 'p')
    header 'CONTENT_TYPE', 'application/json'
    post path, body
  end

  # --- root SWML endpoint -------------------------------------------------

  def test_root_post_unsigned_rejected_with_403
    unsigned_post('/', '{"call_id":"abc"}')

    assert_equal 403, last_response.status
  end

  def test_root_post_signed_accepted
    signed_post('/', '{"call_id":"abc"}')

    assert_equal 200, last_response.status,
                 "expected 200, got #{last_response.status}: #{last_response.body[0, 200]}"
    body = JSON.parse(last_response.body)

    assert body.key?('sections'), 'SWML response should include sections'
  end

  def test_root_post_invalid_signature_rejected
    header 'X-Forwarded-Proto', 'https'
    header 'X-Forwarded-Host',  'signed.example.org'
    header 'X-SignalWire-Signature', 'not-the-real-signature'
    header 'Authorization', AgentSigningKeyHelpers.basic_auth_header('u', 'p')
    header 'CONTENT_TYPE', 'application/json'
    post '/', '{"call_id":"abc"}'

    assert_equal 403, last_response.status
  end

  # --- /post_prompt endpoint ---------------------------------------------

  def test_post_prompt_unsigned_rejected
    unsigned_post('/post_prompt', '{"post_prompt_data":{"raw":"hi"}}')

    assert_equal 403, last_response.status
  end

  def test_post_prompt_signed_accepted
    signed_post('/post_prompt', '{"post_prompt_data":{"raw":"hi"}}')

    assert_equal 200, last_response.status,
                 "expected 200, got #{last_response.status}: #{last_response.body[0, 200]}"
  end

  # --- /swaig endpoint ---------------------------------------------------

  def test_swaig_unsigned_rejected
    unsigned_post('/swaig', '{"function":"x"}')

    assert_equal 403, last_response.status
  end

  # --- non-POST methods unaffected ---------------------------------------

  def test_get_root_does_not_require_signature
    # GETs are not signed by SignalWire and must still pass to the agent.
    header 'Authorization', AgentSigningKeyHelpers.basic_auth_header('u', 'p')
    get '/'

    assert_equal 200, last_response.status,
                 "GET /: expected 200, got #{last_response.status}: #{last_response.body[0, 200]}"
  end

  def test_health_endpoint_still_unauthenticated_and_unsigned
    # /health is publicly mounted and must work regardless of sig config.
    get '/health'

    assert_equal 200, last_response.status
    assert_equal 'healthy', JSON.parse(last_response.body)['status']
  end
end

# ---------------------------------------------------------------------------
# When signing_key is unset, the validator is NOT mounted.
# ---------------------------------------------------------------------------

class AgentWithoutSigningKeyTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @agent ||= SignalWire::AgentBase.new(
      basic_auth: %w[u p],
      suppress_logs: true
    )
    @agent.rack_app
  end

  def test_unsigned_post_works_without_signing_key
    header 'Authorization', 'Basic ' + ['u:p'].pack('m0')
    header 'CONTENT_TYPE', 'application/json'
    post '/', '{"call_id":"abc"}'
    # 200 from the SWML endpoint — proves no validator is in the chain.
    assert_equal 200, last_response.status,
                 "expected 200, got #{last_response.status}: #{last_response.body[0, 200]}"
  end
end
