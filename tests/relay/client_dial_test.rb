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

  CREDENTIAL_ENV_VARS = %w[SIGNALWIRE_PROJECT_ID SIGNALWIRE_API_TOKEN SIGNALWIRE_SPACE].freeze

  def test_client_requires_credentials
    without_credential_env do
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new }
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new(project: 'proj', token: 'tok') }
    end
  end

  # Clear the credential env vars for the duration of the block, restoring
  # any previously-set values afterward.
  def without_credential_env
    saved = CREDENTIAL_ENV_VARS.to_h { |k| [k, ENV.delete(k)] }
    yield
  ensure
    saved.each { |k, v| ENV[k] = v if v }
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
