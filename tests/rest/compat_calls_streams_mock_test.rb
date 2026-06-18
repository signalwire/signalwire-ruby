# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_calls_streams.py.
#
# Each Minitest test mirrors one Python test and asserts on both the SDK
# response shape and the wire request the mock journaled.

require 'minitest/autorun'
require_relative 'mock_test'

class CompatCallsStreamsMockTest < Minitest::Test
  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- start_stream → POST /Calls/{sid}/Streams --------------------------

  def test_start_stream_returns_stream_resource
    result = @client.compat.calls.start_stream(
      'CA_TEST',
      Url: 'wss://example.com/stream',
      Name: 'my-stream'
    )

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('name'),
           "expected stream sid/name in body, got keys #{result.keys.sort.inspect}")
  end

  def test_start_stream_journal_records_post_to_streams_collection
    @client.compat.calls.start_stream('CA_JX1', Url: 'wss://a.b/s', Name: 'strm-x')
    j = MockTest.journal.last
    body = j.body

    assert_equal 'POST', j.method
    assert_equal '/api/laml/2010-04-01/Accounts/test_proj/Calls/CA_JX1/Streams', j.path
    assert_kind_of Hash, body
    assert_equal 'wss://a.b/s', body['Url']
    assert_equal 'strm-x', body['Name']
  end

  # ---- stop_stream → POST .../Streams/{stream_sid} -----------------------

  def test_stop_stream_returns_stream_resource_with_status
    result = @client.compat.calls.stop_stream(
      'CA_T1', 'ST_T1', Status: 'stopped'
    )

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('status'),
           "expected stream sid/status in body, got keys #{result.keys.sort.inspect}")
  end

  def test_stop_stream_journal_records_post_to_specific_stream
    @client.compat.calls.stop_stream(
      'CA_S1', 'ST_S1', Status: 'stopped'
    )
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    assert_equal '/api/laml/2010-04-01/Accounts/test_proj/Calls/CA_S1/Streams/ST_S1', j.path
    assert_kind_of Hash, j.body
    assert_equal 'stopped', j.body['Status']
  end

  # ---- update_recording -------------------------------------------------

  def test_update_recording_returns_recording_resource
    result = @client.compat.calls.update_recording(
      'CA_T2', 'RE_T2', Status: 'paused'
    )

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('status'),
           "expected recording sid/status in body, got keys #{result.keys.sort.inspect}")
  end

  def test_update_recording_journal_records_post_to_specific_recording
    @client.compat.calls.update_recording(
      'CA_R1', 'RE_R1', Status: 'paused'
    )
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    assert_equal '/api/laml/2010-04-01/Accounts/test_proj/Calls/CA_R1/Recordings/RE_R1', j.path
    assert_kind_of Hash, j.body
    assert_equal 'paused', j.body['Status']
  end
end
