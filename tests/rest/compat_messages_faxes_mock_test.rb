# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_messages_faxes.py.
#
# Covers the gap entries for CompatMessages and CompatFaxes:
#
#   - Messages: update, get_media, delete_media
#   - Faxes:    update, list_media, get_media, delete_media

require 'minitest/autorun'
require_relative 'mock_test'

class CompatMessagesFaxesMockTest < Minitest::Test
  # Parallelize: per-client unique-project + auth-scoped harness isolates each test.
  parallelize_me!

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  # ---- Messages.update --------------------------------------------------

  def test_messages_update_returns_message_resource
    result = @client.compat.messages.update('MM_TEST', Body: 'updated body')

    assert_kind_of Hash, result
    assert(result.key?('body') || result.key?('sid'),
           "expected body/sid, got #{result.keys.sort.inspect}")
  end

  def test_messages_update_journal_records_post_to_message
    @client.compat.messages.update('MM_U1', Body: 'x', Status: 'canceled')
    j = @mock.last

    assert_journal_request(j, 'POST', "/api/laml/2010-04-01/Accounts/#{@project}/Messages/MM_U1")
    assert_equal 'x', j.body['Body']
    assert_equal 'canceled', j.body['Status']
  end

  # ---- Messages.get_media ----------------------------------------------

  def test_messages_get_media_returns_media_resource
    result = @client.compat.messages.get_media('MM_GM', 'ME_GM')

    assert_kind_of Hash, result
    assert(result.key?('content_type') || result.key?('sid'),
           "expected content_type/sid, got #{result.keys.sort.inspect}")
  end

  def test_messages_get_media_journal_records_get_to_media_path
    @client.compat.messages.get_media('MM_X', 'ME_X')
    j = @mock.last

    assert_equal 'GET', j.method
    assert_equal "/api/laml/2010-04-01/Accounts/#{@project}/Messages/MM_X/Media/ME_X", j.path
  end

  # ---- Messages.delete_media -------------------------------------------

  def test_messages_delete_media_no_exception
    result = @client.compat.messages.delete_media('MM_DM', 'ME_DM')
    # The SDK's DELETE returns {} on 204 or whatever the mock body is for
    # non-204 responses.  Either way a Hash is expected.
    assert_kind_of Hash, result
  end

  def test_messages_delete_media_journal_records_delete
    @client.compat.messages.delete_media('MM_D', 'ME_D')
    j = @mock.last

    assert_equal 'DELETE', j.method
    assert_equal "/api/laml/2010-04-01/Accounts/#{@project}/Messages/MM_D/Media/ME_D", j.path
  end

  # ---- Faxes.update -----------------------------------------------------

  def test_faxes_update_returns_fax_resource
    result = @client.compat.faxes.update('FX_U', Status: 'canceled')

    assert_kind_of Hash, result
    assert(result.key?('status') || result.key?('direction'),
           "expected status/direction, got #{result.keys.sort.inspect}")
  end

  def test_faxes_update_journal_records_post_with_status
    @client.compat.faxes.update('FX_U2', Status: 'canceled')
    j = @mock.last

    assert_equal 'POST', j.method
    assert_equal "/api/laml/2010-04-01/Accounts/#{@project}/Faxes/FX_U2", j.path
    assert_kind_of Hash, j.body
    assert_equal 'canceled', j.body['Status']
  end

  # ---- Faxes.list_media -------------------------------------------------

  def test_faxes_list_media_returns_paginated_list
    result = @client.compat.faxes.list_media('FX_LM')

    assert_kind_of Hash, result
    assert(result.key?('media') || result.key?('fax_media'),
           "expected media/fax_media, got #{result.keys.sort.inspect}")
  end

  def test_faxes_list_media_journal_records_get_to_fax_media
    @client.compat.faxes.list_media('FX_LM_X')
    j = @mock.last

    assert_equal 'GET', j.method
    assert_equal "/api/laml/2010-04-01/Accounts/#{@project}/Faxes/FX_LM_X/Media", j.path
  end

  # ---- Faxes.get_media --------------------------------------------------

  def test_faxes_get_media_returns_fax_media_resource
    result = @client.compat.faxes.get_media('FX_GM', 'ME_GM')

    assert_kind_of Hash, result
    assert(result.key?('content_type') || result.key?('sid'),
           "expected content_type/sid, got #{result.keys.sort.inspect}")
  end

  def test_faxes_get_media_journal_records_get_to_specific_media
    @client.compat.faxes.get_media('FX_G', 'ME_G')
    j = @mock.last

    assert_equal 'GET', j.method
    assert_equal "/api/laml/2010-04-01/Accounts/#{@project}/Faxes/FX_G/Media/ME_G", j.path
  end

  # ---- Faxes.delete_media ----------------------------------------------

  def test_faxes_delete_media_no_exception
    result = @client.compat.faxes.delete_media('FX_DM', 'ME_DM')

    assert_kind_of Hash, result
  end

  def test_faxes_delete_media_journal_records_delete
    @client.compat.faxes.delete_media('FX_D', 'ME_D')
    j = @mock.last

    assert_equal 'DELETE', j.method
    assert_equal "/api/laml/2010-04-01/Accounts/#{@project}/Faxes/FX_D/Media/ME_D", j.path
  end

  private

  # Assert a journal entry's HTTP method, path, and that it carries a Hash body.
  def assert_journal_request(entry, method, path)
    assert_equal method, entry.method
    assert_equal path, entry.path
    assert_kind_of Hash, entry.body
  end
end
