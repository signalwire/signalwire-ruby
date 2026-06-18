# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_conferences.py.
#
# Covers all Conference symbols: list/get/update on the conference itself
# plus participant, recording, and stream sub-resources.

require 'minitest/autorun'
require_relative 'mock_test'

# Shared mock lifecycle, base paths, and POST-body assertion helper.
module CompatConferencesSupport
  ACCOUNT_BASE = '/api/laml/2010-04-01/Accounts/test_proj'
  CONF_BASE    = "#{ACCOUNT_BASE}/Conferences".freeze

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # Assert the last journaled request was a POST to +path+ with a Hash body,
  # returning that body for further field assertions.
  def assert_post_with_body(journal_entry, path)
    assert_equal 'POST', journal_entry.method
    assert_equal path, journal_entry.path
    assert_kind_of Hash, journal_entry.body
    journal_entry.body
  end
end

class CompatConferencesMockTest < Minitest::Test
  include CompatConferencesSupport

  # ---- Conference itself ----------------------------------------------

  def test_list_returns_paginated_list
    result = @client.compat.conferences.list

    assert_kind_of Hash, result
    # Compat list bodies always carry a 'page' int and a collection key.
    assert(result.key?('conferences'),
           "expected 'conferences' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['conferences']
    assert_kind_of Integer, result['page']
  end

  def test_list_journal_records_get_to_conferences
    @client.compat.conferences.list
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal CONF_BASE, j.path
    refute_nil j.matched_route, 'spec gap: conferences.list'
  end

  def test_get_returns_conference_resource
    result = @client.compat.conferences.get('CF_TEST')

    assert_kind_of Hash, result
    # Conference resources carry friendly_name + status.
    assert(result.key?('friendly_name') || result.key?('status'))
  end

  def test_get_journal_records_get_with_sid
    @client.compat.conferences.get('CF_GETSID')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{CONF_BASE}/CF_GETSID", j.path
  end

  def test_update_returns_updated_conference
    result = @client.compat.conferences.update('CF_X', Status: 'completed')

    assert_kind_of Hash, result
    assert(result.key?('friendly_name') || result.key?('status'))
  end

  def test_update_journal_records_post_with_status
    @client.compat.conferences.update(
      'CF_UPD', Status: 'completed', AnnounceUrl: 'https://a.b'
    )
    body = assert_post_with_body(MockTest.journal.last, "#{CONF_BASE}/CF_UPD")

    assert_equal 'completed', body['Status']
    assert_equal 'https://a.b', body['AnnounceUrl']
  end

  # ---- Participants ---------------------------------------------------

  def test_get_participant_returns_participant
    result = @client.compat.conferences.get_participant('CF_P', 'CA_P')

    assert_kind_of Hash, result
    # Participant resources expose call_sid + conference_sid.
    assert(result.key?('call_sid') || result.key?('conference_sid'))
  end

  def test_get_participant_journal_records_get
    @client.compat.conferences.get_participant('CF_GP', 'CA_GP')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{CONF_BASE}/CF_GP/Participants/CA_GP", j.path
  end

  def test_update_participant_returns_participant_resource
    result = @client.compat.conferences.update_participant('CF_UP', 'CA_UP', Muted: true)

    assert_kind_of Hash, result
    assert(result.key?('call_sid') || result.key?('conference_sid'))
  end

  def test_update_participant_journal_records_post_with_mute_flag
    @client.compat.conferences.update_participant(
      'CF_M', 'CA_M', Muted: true, Hold: false
    )
    body = assert_post_with_body(MockTest.journal.last, "#{CONF_BASE}/CF_M/Participants/CA_M")

    assert body['Muted']
    refute body['Hold']
  end

  def test_remove_participant_returns_empty_or_object
    # 204-style deletes return {} from the SDK; a synthesised response
    # may also return a body. Either is acceptable - what we care about
    # is no exception was raised.
    result = @client.compat.conferences.remove_participant('CF_R', 'CA_R')

    assert_kind_of Hash, result
  end

  def test_remove_participant_journal_records_delete
    @client.compat.conferences.remove_participant('CF_RM', 'CA_RM')
    j = MockTest.journal.last

    assert_equal 'DELETE', j.method
    assert_equal "#{CONF_BASE}/CF_RM/Participants/CA_RM", j.path
  end
end

# Conference recording + stream sub-resources.
class CompatConferencesMediaMockTest < Minitest::Test
  include CompatConferencesSupport

  # ---- Recordings -----------------------------------------------------

  def test_list_recordings_returns_paginated
    result = @client.compat.conferences.list_recordings('CF_LR')

    assert_kind_of Hash, result
    assert(result.key?('recordings'),
           "expected 'recordings' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['recordings']
  end

  def test_list_recordings_journal_records_get
    @client.compat.conferences.list_recordings('CF_LRX')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{CONF_BASE}/CF_LRX/Recordings", j.path
  end

  def test_get_recording_returns_recording_resource
    result = @client.compat.conferences.get_recording('CF_GR', 'RE_GR')

    assert_kind_of Hash, result
    # Recording resources carry call_sid plus channel/status.
    assert(result.key?('sid') || result.key?('call_sid'))
  end

  def test_get_recording_journal_records_get
    @client.compat.conferences.get_recording('CF_GRX', 'RE_GRX')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{CONF_BASE}/CF_GRX/Recordings/RE_GRX", j.path
  end

  def test_update_recording_returns_recording_resource
    result = @client.compat.conferences.update_recording('CF_URC', 'RE_URC', Status: 'paused')

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('status'))
  end

  def test_update_recording_journal_records_post_with_status
    @client.compat.conferences.update_recording('CF_UR', 'RE_UR', Status: 'paused')
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    assert_equal "#{CONF_BASE}/CF_UR/Recordings/RE_UR", j.path
    assert_kind_of Hash, j.body
    assert_equal 'paused', j.body['Status']
  end

  def test_delete_recording_no_exception
    result = @client.compat.conferences.delete_recording('CF_DR', 'RE_DR')

    assert_kind_of Hash, result
  end

  def test_delete_recording_journal_records_delete
    @client.compat.conferences.delete_recording('CF_DRX', 'RE_DRX')
    j = MockTest.journal.last

    assert_equal 'DELETE', j.method
    assert_equal "#{CONF_BASE}/CF_DRX/Recordings/RE_DRX", j.path
  end

  # ---- Streams --------------------------------------------------------

  def test_start_stream_returns_stream_resource
    result = @client.compat.conferences.start_stream('CF_SS', Url: 'wss://a.b/s')

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('name'))
  end

  def test_start_stream_journal_records_post_to_streams
    @client.compat.conferences.start_stream(
      'CF_SSX', Url: 'wss://a.b/s', Name: 'strm'
    )
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    assert_equal "#{CONF_BASE}/CF_SSX/Streams", j.path
    assert_kind_of Hash, j.body
    assert_equal 'wss://a.b/s', j.body['Url']
  end

  def test_stop_stream_returns_stream_resource
    result = @client.compat.conferences.stop_stream(
      'CF_TS', 'ST_TS', Status: 'stopped'
    )

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('status'))
  end

  def test_stop_stream_journal_records_post_to_specific_stream
    @client.compat.conferences.stop_stream(
      'CF_TSX', 'ST_TSX', Status: 'stopped'
    )
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    assert_equal "#{CONF_BASE}/CF_TSX/Streams/ST_TSX", j.path
    assert_kind_of Hash, j.body
    assert_equal 'stopped', j.body['Status']
  end
end
