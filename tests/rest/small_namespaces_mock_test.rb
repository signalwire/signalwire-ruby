# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_small_namespaces_mock.py.
#
# Covers the gaps reported by audit_python_test_coverage.py for namespaces
# that each had only a handful of uncovered methods:
#
#   - addresses, recordings, short_codes, imported_numbers, mfa,
#     sip_profile, number_groups, project.tokens, datasphere.documents,
#     queues

require 'minitest/autorun'
require_relative 'mock_test'

class SmallNamespacesMockTest < Minitest::Test
  RELAY_BASE = '/api/relay/rest'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- Addresses ------------------------------------------------------

  def test_addresses_list
    body = @client.addresses.list(page_size: 10)

    assert_kind_of Hash, body
    assert body.key?('data')
    assert_kind_of Array, body['data']
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/addresses", last.path
    refute_nil last.matched_route
    assert_equal ['10'], last.query_params['page_size']
  end

  def test_addresses_create
    body = @client.addresses.create(
      address_type: 'commercial',
      first_name: 'Ada',
      last_name: 'Lovelace',
      country: 'US'
    )

    assert_kind_of Hash, body
    # An Address resource carries an 'id' field.
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'POST', last.method
    assert_equal "#{RELAY_BASE}/addresses", last.path
    sent = last.body || {}

    assert_equal 'commercial', sent['address_type']
    assert_equal 'Ada', sent['first_name']
    assert_equal 'US', sent['country']
  end

  def test_addresses_get
    body = @client.addresses.get('addr-123')

    assert_kind_of Hash, body
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/addresses/addr-123", last.path
    refute_nil last.matched_route
  end

  def test_addresses_delete
    body = @client.addresses.delete('addr-123')
    # 204 on delete returns {}.
    assert_kind_of Hash, body
    last = MockTest.journal.last

    assert_equal 'DELETE', last.method
    assert_equal "#{RELAY_BASE}/addresses/addr-123", last.path
    assert_includes [200, 202, 204], last.response_status,
                    "unexpected delete status #{last.response_status}"
  end

  # ---- Recordings -----------------------------------------------------

  def test_recordings_list
    body = @client.recordings.list(page_size: 5)

    assert_kind_of Hash, body
    assert body.key?('data')
    assert_kind_of Array, body['data']
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/recordings", last.path
    assert_equal ['5'], last.query_params['page_size']
  end

  def test_recordings_get
    body = @client.recordings.get('rec-123')

    assert_kind_of Hash, body
    # The Recording schema has an 'id' field.
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/recordings/rec-123", last.path
  end

  def test_recordings_delete
    body = @client.recordings.delete('rec-123')

    assert_kind_of Hash, body
    last = MockTest.journal.last

    assert_equal 'DELETE', last.method
    assert_equal "#{RELAY_BASE}/recordings/rec-123", last.path
    assert_includes [200, 202, 204], last.response_status,
                    "unexpected delete status #{last.response_status}"
  end

  # ---- Short Codes ----------------------------------------------------

  def test_short_codes_list
    body = @client.short_codes.list(page_size: 20)

    assert_kind_of Hash, body
    assert body.key?('data')
    assert_kind_of Array, body['data']
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/short_codes", last.path
  end

  def test_short_codes_get
    body = @client.short_codes.get('sc-1')

    assert_kind_of Hash, body
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/short_codes/sc-1", last.path
  end

  def test_short_codes_update
    body = @client.short_codes.update('sc-1', name: 'Marketing SMS')

    assert_kind_of Hash, body
    assert body.key?('id')
    last = MockTest.journal.last
    # short_codes uses PUT for update per CrudResource override.
    assert_equal 'PUT', last.method
    assert_equal "#{RELAY_BASE}/short_codes/sc-1", last.path
    sent = last.body || {}

    assert_equal 'Marketing SMS', sent['name']
  end

  # ---- Imported Numbers -----------------------------------------------

  def test_imported_numbers_create
    body = @client.imported_numbers.create(
      number: '+15551234567',
      sip_username: 'alice',
      sip_password: 'secret',
      sip_proxy: 'sip.example.com'
    )

    assert_kind_of Hash, body
    # The imported-number response has an 'id'.
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'POST', last.method
    assert_equal "#{RELAY_BASE}/imported_phone_numbers", last.path
    sent = last.body || {}

    assert_equal '+15551234567', sent['number']
    assert_equal 'alice', sent['sip_username']
    assert_equal 'sip.example.com', sent['sip_proxy']
  end

  # ---- MFA — voice channel --------------------------------------------

  def test_mfa_call
    body = @client.mfa.call(
      to: '+15551234567',
      from_: '+15559876543',
      message: 'Your code is {code}'
    )

    assert_kind_of Hash, body
    # The mfa response has 'id', 'success', 'channel', 'to'.
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'POST', last.method
    assert_equal "#{RELAY_BASE}/mfa/call", last.path
    sent = last.body || {}

    assert_equal '+15551234567', sent['to']
    assert_equal '+15559876543', sent['from_']
    assert_equal 'Your code is {code}', sent['message']
  end

  # ---- SIP Profile ----------------------------------------------------

  def test_sip_profile_update
    body = @client.sip_profile.update(
      domain: 'myco.sip.signalwire.com',
      default_codecs: %w[PCMU PCMA]
    )

    assert_kind_of Hash, body
    # The SIP profile resource has a 'domain' field.
    assert(body.key?('domain') || body.key?('default_codecs'))
    last = MockTest.journal.last

    assert_equal 'PUT', last.method
    assert_equal "#{RELAY_BASE}/sip_profile", last.path
    sent = last.body || {}

    assert_equal 'myco.sip.signalwire.com', sent['domain']
    assert_equal %w[PCMU PCMA], sent['default_codecs']
  end

  # ---- Number Groups — membership operations --------------------------

  def test_number_groups_list_memberships
    body = @client.number_groups.list_memberships('ng-1', page_size: 10)

    assert_kind_of Hash, body
    assert body.key?('data')
    assert_kind_of Array, body['data']
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/number_groups/ng-1/number_group_memberships", last.path
    assert_equal ['10'], last.query_params['page_size']
  end

  def test_number_groups_delete_membership
    body = @client.number_groups.delete_membership('mem-1')

    assert_kind_of Hash, body
    last = MockTest.journal.last

    assert_equal 'DELETE', last.method
    assert_equal "#{RELAY_BASE}/number_group_memberships/mem-1", last.path
    assert_includes [200, 202, 204], last.response_status,
                    "unexpected delete status #{last.response_status}"
  end

  # ---- Project tokens — update + delete -------------------------------

  def test_project_tokens_update
    body = @client.project.tokens.update('tok-1', name: 'renamed-token')

    assert_kind_of Hash, body
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'PATCH', last.method
    assert_equal '/api/project/tokens/tok-1', last.path
    sent = last.body || {}

    assert_equal 'renamed-token', sent['name']
  end

  def test_project_tokens_delete
    body = @client.project.tokens.delete('tok-1')

    assert_kind_of Hash, body
    last = MockTest.journal.last

    assert_equal 'DELETE', last.method
    assert_equal '/api/project/tokens/tok-1', last.path
    assert_includes [200, 202, 204], last.response_status,
                    "unexpected delete status #{last.response_status}"
  end

  # ---- Datasphere — get_chunk ----------------------------------------

  def test_datasphere_get_chunk
    body = @client.datasphere.documents.get_chunk('doc-1', 'chunk-99')

    assert_kind_of Hash, body
    # The DatasphereChunk schema has an 'id'.
    assert body.key?('id')
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal '/api/datasphere/documents/doc-1/chunks/chunk-99', last.path
  end

  # ---- Queues — get_member -------------------------------------------

  def test_queues_get_member
    body = @client.queues.get_member('q-1', 'mem-7')

    assert_kind_of Hash, body
    # A queue member has 'queue_id' and 'call_id' per the spec example.
    assert(body.key?('queue_id') || body.key?('call_id'))
    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/queues/q-1/members/mem-7", last.path
  end
end
