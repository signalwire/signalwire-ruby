# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_recordings_transcriptions.py.
#
# Both resources expose the same surface (list / get / delete) and use the
# account-scoped LAML path. Six gap entries total:
#
#   - CompatRecordings:    list, get, delete
#   - CompatTranscriptions: list, get, delete

require 'minitest/autorun'
require_relative 'mock_test'

class CompatRecordingsTranscriptionsMockTest < Minitest::Test
  # Parallelize: per-client unique-project + auth-scoped harness isolates each test.
  parallelize_me!

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  def account_base
    "/api/laml/2010-04-01/Accounts/#{@project}"
  end

  # ---- Recordings.list -------------------------------------------------

  def test_recordings_list_returns_paginated
    result = @client.compat.recordings.list

    assert_kind_of Hash, result
    assert(result.key?('recordings'),
           "expected 'recordings' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['recordings']
  end

  def test_recordings_list_journal_records_get
    @client.compat.recordings.list
    j = @mock.last

    assert_equal 'GET', j.method
    assert_equal "#{account_base}/Recordings", j.path
  end

  # ---- Recordings.get --------------------------------------------------

  def test_recordings_get_returns_recording_resource
    result = @client.compat.recordings.get('RE_TEST')

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('call_sid'),
           "expected sid/call_sid, got #{result.keys.sort.inspect}")
  end

  def test_recordings_get_journal_records_get_with_sid
    @client.compat.recordings.get('RE_GET')
    j = @mock.last

    assert_equal 'GET', j.method
    assert_equal "#{account_base}/Recordings/RE_GET", j.path
  end

  # ---- Recordings.delete ----------------------------------------------

  def test_recordings_delete_no_exception
    result = @client.compat.recordings.delete('RE_D')

    assert_kind_of Hash, result
  end

  def test_recordings_delete_journal_records_delete
    @client.compat.recordings.delete('RE_DEL')
    j = @mock.last

    assert_equal 'DELETE', j.method
    assert_equal "#{account_base}/Recordings/RE_DEL", j.path
  end

  # ---- Transcriptions.list --------------------------------------------

  def test_transcriptions_list_returns_paginated
    result = @client.compat.transcriptions.list

    assert_kind_of Hash, result
    assert(result.key?('transcriptions'),
           "expected 'transcriptions' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['transcriptions']
  end

  def test_transcriptions_list_journal_records_get
    @client.compat.transcriptions.list
    j = @mock.last

    assert_equal 'GET', j.method
    assert_equal "#{account_base}/Transcriptions", j.path
  end

  # ---- Transcriptions.get ---------------------------------------------

  def test_transcriptions_get_returns_transcription_resource
    result = @client.compat.transcriptions.get('TR_TEST')

    assert_kind_of Hash, result
    assert(result.key?('sid') || result.key?('duration'),
           "expected sid/duration, got #{result.keys.sort.inspect}")
  end

  def test_transcriptions_get_journal_records_get_with_sid
    @client.compat.transcriptions.get('TR_GET')
    j = @mock.last

    assert_equal 'GET', j.method
    assert_equal "#{account_base}/Transcriptions/TR_GET", j.path
  end

  # ---- Transcriptions.delete ------------------------------------------

  def test_transcriptions_delete_no_exception
    result = @client.compat.transcriptions.delete('TR_D')

    assert_kind_of Hash, result
  end

  def test_transcriptions_delete_journal_records_delete
    @client.compat.transcriptions.delete('TR_DEL')
    j = @mock.last

    assert_equal 'DELETE', j.method
    assert_equal "#{account_base}/Transcriptions/TR_DEL", j.path
  end
end
