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

    assert h.verify_bearer_token(Bearer.new('tok123'))
    refute h.verify_bearer_token(Bearer.new('wrong'))
  end

  def test_verify_bearer_disabled_without_token
    h = handler

    refute h.verify_bearer_token(Bearer.new('anything'))
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
