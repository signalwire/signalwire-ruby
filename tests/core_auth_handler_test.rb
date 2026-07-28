# frozen_string_literal: true

require 'minitest/autorun'
require 'base64'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Real-behavior tests for SignalWire::Core::AuthHandler (parity with Python's
# signalwire.core.auth_handler.AuthHandler). The framework-bound Python methods
# flask_decorator / get_fastapi_dependency are exercised via their native Rack
# equivalents.
class CoreAuthHandlerTest < Minitest::Test
  # Minimal stand-in for SecurityConfig exposing the readers AuthHandler uses.
  class FakeConfig
    attr_reader :bearer_token, :api_key, :api_key_header

    def initialize(user: 'signalwire', password: 'pw', bearer_token: nil,
                   api_key: nil, api_key_header: nil)
      @user = user
      @password = password
      @bearer_token = bearer_token
      @api_key = api_key
      @api_key_header = api_key_header
    end

    def get_basic_auth
      [@user, @password]
    end
  end

  def handler(**)
    SignalWire::Core::AuthHandler.new(FakeConfig.new(**))
  end

  Basic = SignalWire::Core::AuthHandler::BasicCredentials
  Bearer = SignalWire::Core::AuthHandler::BearerCredentials

  def test_verify_basic_auth_accepts_correct
    h = handler(user: 'alice', password: 'secret')

    assert h.verify_basic_auth(Basic.new('alice', 'secret'))
  end

  def test_verify_basic_auth_rejects_wrong_password
    h = handler(user: 'alice', password: 'secret')

    refute h.verify_basic_auth(Basic.new('alice', 'nope'))
    refute h.verify_basic_auth(Basic.new('bob', 'secret'))
  end

  def test_verify_bearer_token
    h = handler(bearer_token: 'tok123')

    assert h.verify_bearer_token(Bearer.new('Bearer', 'tok123'))
    refute h.verify_bearer_token(Bearer.new('Bearer', 'wrong'))
  end

  def test_verify_bearer_disabled_without_token
    h = handler

    refute h.verify_bearer_token(Bearer.new('Bearer', 'anything'))
  end

  def test_verify_api_key
    h = handler(api_key: 'key-abc')

    assert h.verify_api_key('key-abc')
    refute h.verify_api_key('key-xyz')
  end

  def test_get_auth_info_basic_has_username_not_password
    info = handler(user: 'alice', password: 'secret').get_auth_info

    assert_equal 'alice', info['basic']['username']
    refute info['basic'].value?('secret')
  end

  def test_get_auth_info_bearer_and_api_key_hide_secrets
    info = handler(bearer_token: 'tok', api_key: 'k').get_auth_info

    assert info['bearer']['enabled']
    refute info['bearer'].key?('token')
    assert_equal 'X-API-Key', info['api_key']['header']
    refute info['api_key'].key?('key')
  end

  # --- native equivalents of flask_decorator / get_fastapi_dependency ---

  def basic_env(user, pass)
    { 'HTTP_AUTHORIZATION' => "Basic #{Base64.strict_encode64("#{user}:#{pass}")}",
      'REQUEST_METHOD' => 'POST', 'PATH_INFO' => '/', 'REMOTE_ADDR' => '127.0.0.1' }
  end

  def test_rack_middleware_passes_authed_request
    h = handler(user: 'u', password: 'p')
    inner = ->(_env) { [200, {}, ['ok']] }
    app = h.flask_decorator(inner)

    status, = app.call(basic_env('u', 'p'))

    assert_equal 200, status
  end

  def test_rack_middleware_rejects_bad_creds
    h = handler(user: 'u', password: 'p')
    inner = ->(_env) { [200, {}, ['ok']] }
    app = h.flask_decorator(inner)

    status, headers, = app.call(basic_env('u', 'wrong'))

    assert_equal 401, status
    assert headers.key?('www-authenticate')
  end

  def test_rack_middleware_accepts_bearer
    h = handler(bearer_token: 'tok')
    inner = ->(_env) { [200, {}, ['ok']] }
    app = h.flask_decorator(inner)

    status, = app.call({ 'HTTP_AUTHORIZATION' => 'Bearer tok', 'REQUEST_METHOD' => 'GET',
                         'PATH_INFO' => '/', 'REMOTE_ADDR' => '1.2.3.4' })

    assert_equal 200, status
  end

  def test_rack_middleware_accepts_api_key
    h = handler(api_key: 'secretkey', api_key_header: 'X-API-Key')
    inner = ->(_env) { [200, {}, ['ok']] }
    app = h.flask_decorator(inner)

    status, = app.call({ 'HTTP_X_API_KEY' => 'secretkey', 'REQUEST_METHOD' => 'GET',
                         'PATH_INFO' => '/', 'REMOTE_ADDR' => '1.2.3.4' })

    assert_equal 200, status
  end

  def test_rack_dependency_returns_result_when_authed
    h = handler(user: 'u', password: 'p')
    dep = h.get_fastapi_dependency

    result = dep.call(basic_env('u', 'p'))

    assert_equal true, result['authenticated']
    assert_equal 'basic', result['method']
  end

  def test_rack_dependency_raises_when_required_and_unauthed
    h = handler(user: 'u', password: 'p')
    dep = h.get_fastapi_dependency(optional: false)

    err = assert_raises(SignalWire::Core::AuthError) { dep.call(basic_env('u', 'bad')) }
    assert_equal 401, err.response[0]
  end

  def test_rack_dependency_optional_does_not_raise
    h = handler(user: 'u', password: 'p')
    dep = h.get_fastapi_dependency(optional: true)

    result = dep.call(basic_env('u', 'bad'))

    assert_equal false, result['authenticated']
    assert_nil result['method']
  end
end

# The credential CARRIERS themselves: both must expose exactly the fields the
# reference's carrier does (oracle: signalwire.core.auth_handler.BasicCredentials
# {username, password} / BearerCredentials {scheme, credentials} -- porting-sdk
# dcff742's structural filler for FastAPI's HTTPBasicCredentials /
# HTTPAuthorizationCredentials). `scheme` was absent from the Ruby Struct
# entirely until 2026-07-28, so nothing pinned the header split.
class CoreAuthCredentialsTest < Minitest::Test
  Basic = SignalWire::Core::AuthHandler::BasicCredentials
  Bearer = SignalWire::Core::AuthHandler::BearerCredentials

  def handler(**)
    SignalWire::Core::AuthHandler.new(CoreAuthHandlerTest::FakeConfig.new(**))
  end

  def test_bearer_credentials_carries_scheme_and_credentials
    c = Bearer.new('Bearer', 'tok123')

    assert_equal 'Bearer', c.scheme
    assert_equal 'tok123', c.credentials
    assert_equal %i[scheme credentials], Bearer.members
  end

  def test_basic_credentials_carries_username_and_password
    c = Basic.new('alice', 'secret')

    assert_equal 'alice', c.username
    assert_equal 'secret', c.password
    assert_equal %i[username password], Basic.members
  end

  # The Rack bearer path must populate scheme from the header, not fold the
  # whole header into credentials (which would make the token compare fail).
  def test_rack_bearer_path_splits_scheme_from_token
    h = handler(bearer_token: 'tok-with-scheme')
    dep = h.rack_dependency(optional: true)
    result = dep.call({ 'HTTP_AUTHORIZATION' => 'Bearer tok-with-scheme',
                        'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/',
                        'REMOTE_ADDR' => '1.2.3.4' })

    assert result['authenticated'], 'bearer header must authenticate after the scheme/token split'
    assert_equal 'bearer', result['method']
  end
end

# RFC 7235 makes the auth-scheme token case-INSENSITIVE, and RFC 7617 requires a
# colon in the decoded Basic payload. The reference (fastapi.security.http)
# partitions the header on the FIRST SPACE, compares `scheme.lower()` against
# "basic"/"bearer", and for Basic does `username, separator, password =
# data.partition(":")` then `if not separator: raise` -- a colon-less payload is
# rejected outright, never defaulted to an empty password.
class CoreAuthSchemeAndColonTest < Minitest::Test
  def handler(**)
    SignalWire::Core::AuthHandler.new(CoreAuthHandlerTest::FakeConfig.new(**))
  end

  def env(header)
    { 'HTTP_AUTHORIZATION' => header, 'REQUEST_METHOD' => 'GET',
      'PATH_INFO' => '/', 'REMOTE_ADDR' => '1.2.3.4' }
  end

  def auth(handler, header)
    handler.rack_dependency(optional: true).call(env(header))
  end

  def basic_header(scheme, payload)
    "#{scheme} #{Base64.strict_encode64(payload)}"
  end

  # --- (a) case-insensitive scheme: ACCEPT ------------------------------------

  def test_lowercase_bearer_scheme_is_accepted
    h = handler(bearer_token: 'tok123')

    %w[bearer BEARER BeArEr Bearer].each do |scheme|
      result = auth(h, "#{scheme} tok123")

      assert result['authenticated'], "scheme #{scheme.inspect} must authenticate (RFC 7235)"
      assert_equal 'bearer', result['method']
    end
  end

  def test_lowercase_basic_scheme_is_accepted
    h = handler(user: 'alice', password: 'secret')

    %w[basic BASIC BaSiC Basic].each do |scheme|
      result = auth(h, basic_header(scheme, 'alice:secret'))

      assert result['authenticated'], "scheme #{scheme.inspect} must authenticate (RFC 7235)"
      assert_equal 'basic', result['method']
    end
  end

  # --- (a) case-insensitive scheme: still REJECT the wrong ones ---------------

  def test_wrong_schemes_are_still_rejected_on_the_bearer_path
    h = handler(user: 'nobody', password: 'nothing', bearer_token: 'tok123')

    ['Digest tok123', 'Negotiate tok123', 'Bearerx tok123', 'bearerx tok123',
     'Basic tok123', 'tok123'].each do |header|
      refute auth(h, header)['authenticated'], "#{header.inspect} must NOT authenticate"
    end
  end

  def test_wrong_schemes_are_still_rejected_on_the_basic_path
    h = handler(user: 'alice', password: 'secret')
    encoded = Base64.strict_encode64('alice:secret')

    ["Digest #{encoded}", "Negotiate #{encoded}", "Basicx #{encoded}",
     "basicx #{encoded}", "Bearer #{encoded}", encoded].each do |header|
      refute auth(h, header)['authenticated'], "#{header.inspect} must NOT authenticate"
    end
  end

  def test_scheme_is_carried_verbatim_into_the_bearer_carrier
    h = handler(bearer_token: 'tok123')
    seen = nil
    h.define_singleton_method(:verify_bearer_token) do |credentials|
      seen = credentials
      super(credentials)
    end

    auth(h, 'bearer tok123')

    assert_equal 'bearer', seen.scheme, 'the scheme must be carried verbatim, not normalized'
    assert_equal 'tok123', seen.credentials
  end

  # --- (b) a colon-less Basic payload must be REJECTED ------------------------

  def test_colonless_basic_payload_is_rejected
    h = handler(user: 'bob', password: '')

    refute auth(h, basic_header('Basic', 'bob'))['authenticated'],
           'a decoded Basic payload with NO colon must be rejected (RFC 7617 / reference partition-separator check)'
  end

  def test_colonless_basic_payload_is_rejected_even_when_the_password_is_empty_by_config
    h = handler(user: 'bob', password: nil)

    refute auth(h, basic_header('Basic', 'bob'))['authenticated'],
           'no colon means no credential pair, regardless of the configured password'
  end

  def test_empty_password_with_an_explicit_trailing_colon_is_still_parsed
    h = handler(user: 'bob', password: '')

    assert auth(h, basic_header('Basic', 'bob:'))['authenticated'],
           'an explicit trailing colon IS a separator -- username "bob", empty password'
  end

  def test_password_containing_a_colon_keeps_everything_after_the_first_one
    h = handler(user: 'alice', password: 'p:a:s:s')

    assert auth(h, basic_header('Basic', 'alice:p:a:s:s'))['authenticated'],
           'only the FIRST colon separates; the rest belongs to the password'
  end
end
