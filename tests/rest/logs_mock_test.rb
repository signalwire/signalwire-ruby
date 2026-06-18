# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_logs_mock.py.
#
# The Logs namespace fans out across four spec docs (message/voice/fax/logs)
# because each kind of log lives at a different sub-API. Each sub-resource
# has a small surface (list, get, optional list_events).

require 'minitest/autorun'
require_relative 'mock_test'

class LogsMockTest < Minitest::Test
  # Parallelize: per-client unique-project + auth-scoped harness isolates each test.
  parallelize_me!

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  # ---- Message Logs — /api/messaging/logs -----------------------------

  def test_messages_list_returns_dict
    body = @client.logs.messages.list

    assert_kind_of Hash, body

    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal '/api/messaging/logs', last.path
    assert_equal 'message.list_message_logs', last.matched_route
  end

  def test_messages_get_uses_id_in_path
    body = @client.logs.messages.get('ml-42')

    assert_kind_of Hash, body
    # Single-log endpoint returns one resource object, not a collection.

    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal '/api/messaging/logs/ml-42', last.path
    refute_nil last.matched_route, 'spec gap: message log retrieve'
  end

  # ---- Voice Logs — /api/voice/logs -----------------------------------

  def test_voice_list_returns_dict
    body = @client.logs.voice.list

    assert_kind_of Hash, body

    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal '/api/voice/logs', last.path
    assert_equal 'voice.list_voice_logs', last.matched_route
  end

  def test_voice_get_uses_id_in_path
    body = @client.logs.voice.get('vl-99')

    assert_kind_of Hash, body

    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal '/api/voice/logs/vl-99', last.path
  end

  # ---- Fax Logs — /api/fax/logs ---------------------------------------

  def test_fax_list_returns_dict
    body = @client.logs.fax.list

    assert_kind_of Hash, body

    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal '/api/fax/logs', last.path
    assert_equal 'fax.list_fax_logs', last.matched_route
  end

  def test_fax_get_uses_id_in_path
    body = @client.logs.fax.get('fl-7')

    assert_kind_of Hash, body

    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal '/api/fax/logs/fl-7', last.path
  end

  # ---- Conference Logs — /api/logs/conferences ------------------------

  def test_conferences_list_returns_dict
    body = @client.logs.conferences.list

    assert_kind_of Hash, body

    last = @mock.last

    assert_equal 'GET', last.method
    # The conferences logs spec lives under /api/logs/conferences.
    assert_equal '/api/logs/conferences', last.path
    assert_equal 'logs.list_conferences', last.matched_route
  end
end
