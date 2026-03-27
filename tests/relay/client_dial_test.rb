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

  def test_client_requires_credentials
    old_project = ENV.delete('SIGNALWIRE_PROJECT_ID')
    old_token = ENV.delete('SIGNALWIRE_API_TOKEN')
    old_space = ENV.delete('SIGNALWIRE_SPACE')
    begin
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new }
      assert_raises(ArgumentError) { SignalWire::Relay::Client.new(project: 'proj', token: 'tok') }
    ensure
      ENV['SIGNALWIRE_PROJECT_ID'] = old_project if old_project
      ENV['SIGNALWIRE_API_TOKEN'] = old_token if old_token
      ENV['SIGNALWIRE_SPACE'] = old_space if old_space
    end
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
