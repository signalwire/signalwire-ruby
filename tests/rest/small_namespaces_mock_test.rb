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

# Shared setup + journal assertions for the small-namespace mock tests.
module SmallNamespacesHelpers
  # Parallelize: each test's client uses a unique project + auth-scoped harness,
  # so the shared mock is concurrency-safe. Parallelism stress-proves isolation.
  def self.included(base)
    base.parallelize_me!
  end

  RELAY_BASE = '/api/relay/rest'

  def setup
    h = MockTest.client
    @client  = h[:client]
    @mock    = h[:mock]
    @project = h[:project]
  end

  # Assert the last journaled request used +method+ against +path+ (matched).
  # Returns the journal entry for further assertions.
  def assert_request(method, path)
    last = @mock.last

    assert_equal method, last.method
    assert_equal path, last.path
    refute_nil last.matched_route
    last
  end

  # Assert each expected key/value pair is present in the journaled body.
  def assert_sent_body(entry, expected)
    sent = entry.body || {}

    expected.each { |k, v| assert_equal(v, sent[k], "body[#{k.inspect}]") }
  end
end

class SmallNamespacesMockTest < Minitest::Test
  include SmallNamespacesHelpers

  # ---- Addresses ------------------------------------------------------

  def test_addresses_list
    body = @client.addresses.list(page_size: 10)

    assert_kind_of Hash, body
    assert body.key?('data')
    assert_kind_of Array, body['data']
    last = assert_request('GET', "#{RELAY_BASE}/addresses")

    assert_equal ['10'], last.query_params['page_size']
  end

  # The generated addresses.create requires the full spec address field set.
  ADDRESS_CREATE = {
    label: 'HQ', country: 'US', first_name: 'Ada', last_name: 'Lovelace',
    street_number: '1', street_name: 'Analytical Ave', city: 'London',
    state: 'CA', postal_code: '94000', address_type: 'commercial'
  }.freeze

  def test_addresses_create
    body = @client.addresses.create(**ADDRESS_CREATE)

    assert_kind_of Hash, body
    # An Address resource carries an 'id' field.
    assert body.key?('id')
    last = assert_request('POST', "#{RELAY_BASE}/addresses")
    assert_sent_body(last, 'address_type' => 'commercial', 'first_name' => 'Ada', 'country' => 'US')
  end

  def test_addresses_get
    body = @client.addresses.get('addr-123')

    assert_kind_of Hash, body
    assert body.key?('id')
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/addresses/addr-123", last.path
    refute_nil last.matched_route
  end

  def test_addresses_delete
    body = @client.addresses.delete('addr-123')
    # 204 on delete returns {}.
    assert_kind_of Hash, body
    last = @mock.last

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
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/recordings", last.path
    assert_equal ['5'], last.query_params['page_size']
  end

  def test_recordings_get
    body = @client.recordings.get('rec-123')

    assert_kind_of Hash, body
    # The Recording schema has an 'id' field.
    assert body.key?('id')
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/recordings/rec-123", last.path
  end

  def test_recordings_delete
    body = @client.recordings.delete('rec-123')

    assert_kind_of Hash, body
    last = @mock.last

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
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/short_codes", last.path
  end

  def test_short_codes_get
    body = @client.short_codes.get('sc-1')

    assert_kind_of Hash, body
    assert body.key?('id')
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/short_codes/sc-1", last.path
  end

  def test_short_codes_update
    body = @client.short_codes.update('sc-1', name: 'Marketing SMS', message_handler: 'laml_webhooks')

    assert_kind_of Hash, body
    assert body.key?('id')
    last = @mock.last
    # short_codes uses PUT for update per CrudResource override.
    assert_equal 'PUT', last.method
    assert_equal "#{RELAY_BASE}/short_codes/sc-1", last.path
    sent = last.body || {}

    assert_equal 'Marketing SMS', sent['name']
  end
end

# Second half of the small-namespace coverage (split to keep each test class
# under the size limit). Shares setup/assertions via SmallNamespacesHelpers.
class SmallNamespacesMockTestPartTwo < Minitest::Test
  include SmallNamespacesHelpers

  # ---- Imported Numbers -----------------------------------------------

  def test_imported_numbers_create
    body = @client.imported_numbers.create(
      number: '+15551234567', number_type: 'sip',
      sip_username: 'alice', sip_password: 'secret', sip_proxy: 'sip.example.com'
    )

    assert_kind_of Hash, body
    # The imported-number response has an 'id'.
    assert body.key?('id')
    last = assert_request('POST', "#{RELAY_BASE}/imported_phone_numbers")
    assert_sent_body(last, 'number' => '+15551234567', 'sip_username' => 'alice',
                           'sip_proxy' => 'sip.example.com')
  end

  # ---- MFA — voice channel --------------------------------------------

  def test_mfa_call
    body = @client.mfa.call(
      to: '+15551234567',
      from: '+15559876543',
      message: 'Your code is {code}'
    )

    assert_kind_of Hash, body
    # The mfa response has 'id', 'success', 'channel', 'to'.
    assert body.key?('id')
    last = assert_request('POST', "#{RELAY_BASE}/mfa/call")
    assert_sent_body(last, 'to' => '+15551234567', 'from' => '+15559876543',
                           'message' => 'Your code is {code}')
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
    last = assert_request('PUT', "#{RELAY_BASE}/sip_profile")
    assert_sent_body(last, 'domain' => 'myco.sip.signalwire.com', 'default_codecs' => %w[PCMU PCMA])
  end

  # ---- Number Groups — membership operations --------------------------

  def test_number_groups_list_memberships
    body = @client.number_groups.list_memberships('ng-1', page_size: 10)

    assert_kind_of Hash, body
    assert body.key?('data')
    assert_kind_of Array, body['data']
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/number_groups/ng-1/number_group_memberships", last.path
    assert_equal ['10'], last.query_params['page_size']
  end

  def test_number_groups_delete_membership
    body = @client.number_groups.delete_membership('mem-1')

    assert_kind_of Hash, body
    last = @mock.last

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
    last = @mock.last

    assert_equal 'PATCH', last.method
    assert_equal '/api/project/tokens/tok-1', last.path
    sent = last.body || {}

    assert_equal 'renamed-token', sent['name']
  end

  def test_project_tokens_delete
    body = @client.project.tokens.delete('tok-1')

    assert_kind_of Hash, body
    last = @mock.last

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
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal '/api/datasphere/documents/doc-1/chunks/chunk-99', last.path
  end

  # ---- Queues — get_member -------------------------------------------

  def test_queues_get_member
    body = @client.queues.get_member('q-1', 'mem-7')

    assert_kind_of Hash, body
    # A queue member has 'queue_id' and 'call_id' per the spec example.
    assert(body.key?('queue_id') || body.key?('call_id'))
    last = @mock.last

    assert_equal 'GET', last.method
    assert_equal "#{RELAY_BASE}/queues/q-1/members/mem-7", last.path
  end
end
