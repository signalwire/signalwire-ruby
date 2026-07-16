# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/relay/constants'
require_relative '../../lib/signalwire/relay/relay_event'
require_relative '../../lib/signalwire/relay/action'
require_relative '../../lib/signalwire/relay/call'
require_relative '../../lib/signalwire/relay/message'
require_relative '../../lib/signalwire/relay/client'

class RelayClientDialTest < Minitest::Test
  def test_client_class_exists
    assert defined?(SignalWire::Relay::Client)
  end

  CREDENTIAL_ENV_VARS = %w[
    SIGNALWIRE_PROJECT_ID SIGNALWIRE_API_TOKEN SIGNALWIRE_SPACE SIGNALWIRE_JWT_TOKEN
  ].freeze

  def test_client_requires_credentials
    without_credential_env do
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new }
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new(project: 'proj', token: 'tok') }
    end
  end

  # SIGNALWIRE_JWT_TOKEN is a documented auth knob (relay/README.md, the
  # client reference, getting-started): jwt_token falls back to it, and JWT
  # auth is a self-contained alternative to project+token. Mirrors the Python
  # reference (`self.jwt_token = jwt_token or os.environ["SIGNALWIRE_JWT_TOKEN"]`).
  # without_credential_env clears SIGNALWIRE_JWT_TOKEN too, so a value set
  # inside the block is restored (deleted) on exit — no inline teardown needed.
  def test_jwt_token_env_var_fallback_satisfies_credentials
    without_credential_env do
      ENV['SIGNALWIRE_JWT_TOKEN'] = 'env-jwt-eyJ.aaa.bbb'
      # No project/token needed: the JWT env var alone satisfies validation.
      client = SignalWire::Relay::Client.new(space: 'example.signalwire.com')
      params = auth_params(client)

      assert_equal({ 'jwt_token' => 'env-jwt-eyJ.aaa.bbb' }, params['authentication'])
    end
  end

  # An explicit jwt_token: kwarg wins over the env var.
  def test_jwt_token_kwarg_overrides_env
    without_credential_env do
      ENV['SIGNALWIRE_JWT_TOKEN'] = 'env-jwt'
      client = SignalWire::Relay::Client.new(
        jwt_token: 'explicit-jwt', space: 'example.signalwire.com'
      )

      assert_equal({ 'jwt_token' => 'explicit-jwt' }, auth_params(client)['authentication'])
    end
  end

  # Drive the private auth-frame builder to read the resolved credentials.
  def auth_params(client)
    {}.tap { |params| client.send(:apply_auth_credentials, params) }
  end

  # Clear the credential env vars for the duration of the block, then fully
  # restore the prior state afterward. Full restore matters because a block may
  # SET one of these vars (e.g. the JWT-fallback tests): a var that was absent
  # before the block must be deleted again, not left leaking into later tests.
  def without_credential_env
    saved = CREDENTIAL_ENV_VARS.to_h { |k| [k, ENV.delete(k)] }
    yield
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV.store(k, v) }
  end

  def test_client_creation_with_options
    client = SignalWire::Relay::Client.new(
      project: 'test-project', token: 'test-token', space: 'example.signalwire.com'
    )

    assert_equal 'test-project', client.project_id
    assert_nil client.protocol
  end

  def test_client_creation_with_short_space
    client = SignalWire::Relay::Client.new(
      project: 'test-project', token: 'test-token', space: 'myspace'
    )

    assert_equal 'test-project', client.project_id
  end

  def test_relay_error
    err = SignalWire::Relay::RelayError.new(404, 'Not found')

    assert_equal 404, err.code
    assert_equal 'Not found', err.error_message
    assert_match(/404/, err.message)
  end
end
