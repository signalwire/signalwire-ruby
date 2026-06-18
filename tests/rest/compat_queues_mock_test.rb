# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_queues.py.
#
# Covers CompatQueues.update, list_members, get_member, dequeue_member.

require 'minitest/autorun'
require_relative 'mock_test'

class CompatQueuesMockTest < Minitest::Test
  ACCOUNT_BASE = '/api/laml/2010-04-01/Accounts/test_proj'
  QUEUES_BASE  = "#{ACCOUNT_BASE}/Queues".freeze

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- update ----------------------------------------------------------

  def test_update_returns_queue_resource
    result = @client.compat.queues.update('QU_U', FriendlyName: 'updated')

    assert_kind_of Hash, result
    # Queue resources expose friendly_name + sid + max_size.
    assert(result.key?('friendly_name') || result.key?('sid'))
  end

  # Assert the last journal entry was a POST to +path+ with a Hash body,
  # returning that body for further per-field assertions.
  def assert_post_body(path)
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    assert_equal path, j.path
    assert_kind_of Hash, j.body
    j.body
  end

  def test_update_journal_records_post_with_friendly_name
    @client.compat.queues.update('QU_UU', FriendlyName: 'renamed', MaxSize: 200)
    body = assert_post_body("#{QUEUES_BASE}/QU_UU")

    assert_equal 'renamed', body['FriendlyName']
    assert_equal 200, body['MaxSize']
  end

  # ---- list_members ---------------------------------------------------

  def test_list_members_returns_paginated_members
    result = @client.compat.queues.list_members('QU_LM')

    assert_kind_of Hash, result
    assert(result.key?('queue_members'),
           "expected 'queue_members' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['queue_members']
  end

  def test_list_members_journal_records_get
    @client.compat.queues.list_members('QU_LMX')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{QUEUES_BASE}/QU_LMX/Members", j.path
  end

  # ---- get_member -----------------------------------------------------

  def test_get_member_returns_member_resource
    result = @client.compat.queues.get_member('QU_GM', 'CA_GM')

    assert_kind_of Hash, result
    # Member resources expose call_sid + queue_sid + position.
    assert(result.key?('call_sid') || result.key?('queue_sid'))
  end

  def test_get_member_journal_records_get
    @client.compat.queues.get_member('QU_GMX', 'CA_GMX')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{QUEUES_BASE}/QU_GMX/Members/CA_GMX", j.path
  end

  # ---- dequeue_member -------------------------------------------------

  def test_dequeue_member_returns_member_resource
    result = @client.compat.queues.dequeue_member(
      'QU_DM', 'CA_DM', Url: 'https://a.b'
    )

    assert_kind_of Hash, result
    assert(result.key?('call_sid') || result.key?('queue_sid'))
  end

  def test_dequeue_member_journal_records_post_with_url
    @client.compat.queues.dequeue_member(
      'QU_DMX', 'CA_DMX', Url: 'https://a.b/url', Method: 'POST'
    )
    body = assert_post_body("#{QUEUES_BASE}/QU_DMX/Members/CA_DMX")

    assert_equal 'https://a.b/url', body['Url']
    assert_equal 'POST', body['Method']
  end
end
