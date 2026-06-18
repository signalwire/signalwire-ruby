# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_accounts.py.
#
# Drives client.compat.accounts.* against the real mock_signalwire HTTP
# server. Each test asserts on both the SDK return value and the recorded
# request journal so neither half is allowed to drift.

require 'minitest/autorun'
require_relative 'mock_test'

class CompatAccountsMockTest < Minitest::Test
  ACCOUNTS_BASE = '/api/laml/2010-04-01/Accounts'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # Assert a journaled response carried a 2xx/3xx status.
  def assert_success_status(journal_entry)
    status = journal_entry.response_status

    assert(status >= 200 && status < 400, "unexpected status #{status}")
  end

  # Assert a journaled request carried no (or empty) body.
  def assert_no_body(journal_entry)
    body = journal_entry.body

    assert(body.nil? || body == '' || body == {}, "should not have a body, got #{body.inspect}")
  end

  # ---- create ----------------------------------------------------------

  def test_create_returns_account_resource
    result = @client.compat.accounts.create(FriendlyName: 'Sub-A')
    # Synthesised response carries an Account body with friendly_name.
    assert_kind_of Hash, result
    assert(result.key?('friendly_name'),
           "missing 'friendly_name' in #{result.keys.sort.inspect}")
  end

  def test_create_journal_records_post_to_accounts
    @client.compat.accounts.create(FriendlyName: 'Sub-B')
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    # Accounts.create lives at the top-level Accounts collection - no
    # AccountSid prefix.
    assert_equal ACCOUNTS_BASE, j.path
    assert_kind_of Hash, j.body
    assert_equal 'Sub-B', j.body['FriendlyName']
    assert_success_status(j)
  end

  # ---- get -------------------------------------------------------------

  def test_get_returns_account_for_sid
    result = @client.compat.accounts.get('AC123')

    assert_kind_of Hash, result
    # The retrieve endpoint synthesizes a single Account body.
    assert result.key?('friendly_name')
  end

  def test_get_journal_records_get_with_sid
    @client.compat.accounts.get('AC_SAMPLE_SID')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{ACCOUNTS_BASE}/AC_SAMPLE_SID", j.path
    assert_no_body(j) # GET should not carry a request body.
    refute_nil j.matched_route, 'spec gap: account-get should match a route'
  end

  # ---- update ----------------------------------------------------------

  def test_update_returns_updated_account
    result = @client.compat.accounts.update('AC123', FriendlyName: 'Renamed')

    assert_kind_of Hash, result
    assert result.key?('friendly_name')
  end

  def test_update_journal_records_post_to_account_path
    @client.compat.accounts.update('AC_X', FriendlyName: 'NewName')
    j = MockTest.journal.last
    # Twilio-compat update is POST (not PATCH/PUT).
    assert_equal 'POST', j.method
    assert_equal "#{ACCOUNTS_BASE}/AC_X", j.path
    assert_kind_of Hash, j.body
    assert_equal 'NewName', j.body['FriendlyName']
  end
end
