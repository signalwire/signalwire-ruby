# frozen_string_literal: true

# Mock-backed REST coverage tests for the relay-rest spec group.
#
# Drives the real Ruby REST SDK against the porting-sdk mock_signalwire server
# and asserts that every canonical relay-rest route is exercised on the correct
# path with BOTH a success (2xx) AND an error (non-2xx) response, so the
# rest_coverage checker reports the group as fully covered.
#
# Accepted gaps (no relay-rest namespace in the SDK; identical to Python):
#   - SIP endpoints (5):       create/list/retrieve/update/delete_sip_endpoint
#   - domain_applications (5): create/list/retrieve/update/delete_domain_application
#
# Everything else (phone_numbers, addresses, verified_caller_ids + the
# verification flow, queues + members, recordings, number_groups + memberships,
# short_codes, imported_phone_numbers, mfa, sip_profile, lookup, and the 10DLC
# registry) is covered below.

require 'minitest/autorun'
require_relative 'mock_test'

# Shared fixture + journal/scenario assertion helpers for the relay-rest
# coverage classes below.
module RelayCoverageHelpers
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

  # Assert the last journaled request's method + path, and that it dispatched to
  # the named canonical route. Returns the journal entry for further assertions.
  def assert_route(method, path, route)
    last = @mock.last

    assert_equal method, last.method
    assert_equal path, last.path
    assert_equal route, last.matched_route
    last
  end

  # Stage a one-shot error on +route+, invoke +blk+, and assert it raises a
  # SignalWire::REST::SignalWireRestError with the staged status, that the same
  # status was journaled, and that the failing request hit +route+.
  def assert_error(route, status: 404, &)
    @mock.push_scenario(route, status: status, response: { 'error' => 'mock-error' })
    err = assert_raises(SignalWire::REST::SignalWireRestError, &)

    assert_equal status, err.status_code
    assert_equal status, @mock.last.response_status
    assert_equal route, @mock.last.matched_route
  end

  # Assert each expected key/value pair is present in the journaled body.
  def assert_sent_body(entry, expected)
    sent = entry.body || {}

    expected.each { |k, v| assert_equal(v, sent[k], "body[#{k.inspect}]") }
  end
end

# Phone numbers + addresses.
class RelayCoveragePhoneNumbersMockTest < Minitest::Test
  include RelayCoverageHelpers

  # ---- Phone numbers --------------------------------------------------

  def test_phone_numbers_list
    assert_kind_of Hash, @client.phone_numbers.list
    assert_route('GET', "#{RELAY_BASE}/phone_numbers", 'relay-rest.list_phone_numbers')
  end

  def test_phone_numbers_list_error
    assert_error('relay-rest.list_phone_numbers') { @client.phone_numbers.list }
  end

  def test_phone_numbers_search
    assert_kind_of Hash, @client.phone_numbers.search(areacode: '415')
    assert_route('GET', "#{RELAY_BASE}/phone_numbers/search", 'relay-rest.search_available_phone_numbers')
  end

  def test_phone_numbers_search_error
    assert_error('relay-rest.search_available_phone_numbers') { @client.phone_numbers.search(areacode: '415') }
  end

  def test_phone_numbers_purchase
    assert_kind_of Hash, @client.phone_numbers.create(number: '+15551230000')
    last = assert_route('POST', "#{RELAY_BASE}/phone_numbers", 'relay-rest.purchase_phone_number')
    assert_sent_body(last, 'number' => '+15551230000')
  end

  def test_phone_numbers_purchase_error
    assert_error('relay-rest.purchase_phone_number') { @client.phone_numbers.create(number: '+15551230000') }
  end

  def test_phone_numbers_get
    assert_kind_of Hash, @client.phone_numbers.get('pn-1')
    assert_route('GET', "#{RELAY_BASE}/phone_numbers/pn-1", 'relay-rest.retrieve_phone_number')
  end

  def test_phone_numbers_get_error
    assert_error('relay-rest.retrieve_phone_number') { @client.phone_numbers.get('pn-1') }
  end

  def test_phone_numbers_update_uses_put
    assert_kind_of Hash, @client.phone_numbers.update('pn-1', name: 'Main line')
    last = assert_route('PUT', "#{RELAY_BASE}/phone_numbers/pn-1", 'relay-rest.update_phone_number')
    assert_sent_body(last, 'name' => 'Main line')
  end

  def test_phone_numbers_update_error
    assert_error('relay-rest.update_phone_number') { @client.phone_numbers.update('pn-1', name: 'x') }
  end

  def test_phone_numbers_release
    assert_kind_of Hash, @client.phone_numbers.delete('pn-1')
    assert_route('DELETE', "#{RELAY_BASE}/phone_numbers/pn-1", 'relay-rest.release_phone_number')
  end

  def test_phone_numbers_release_error
    assert_error('relay-rest.release_phone_number') { @client.phone_numbers.delete('pn-1') }
  end

  # ---- Addresses ------------------------------------------------------

  def test_addresses_list
    assert_kind_of Hash, @client.addresses.list
    assert_route('GET', "#{RELAY_BASE}/addresses", 'relay-rest.list_addresses')
  end

  def test_addresses_list_error
    assert_error('relay-rest.list_addresses') { @client.addresses.list }
  end

  def test_addresses_create
    assert_kind_of Hash, @client.addresses.create(address_type: 'commercial', country: 'US')
    last = assert_route('POST', "#{RELAY_BASE}/addresses", 'relay-rest.create_address')
    assert_sent_body(last, 'address_type' => 'commercial', 'country' => 'US')
  end

  def test_addresses_create_error
    assert_error('relay-rest.create_address') { @client.addresses.create(country: 'US') }
  end

  def test_addresses_get
    assert_kind_of Hash, @client.addresses.get('addr-1')
    assert_route('GET', "#{RELAY_BASE}/addresses/addr-1", 'relay-rest.get_address')
  end

  def test_addresses_get_error
    assert_error('relay-rest.get_address') { @client.addresses.get('addr-1') }
  end

  def test_addresses_delete
    assert_kind_of Hash, @client.addresses.delete('addr-1')
    assert_route('DELETE', "#{RELAY_BASE}/addresses/addr-1", 'relay-rest.delete_address')
  end

  def test_addresses_delete_error
    assert_error('relay-rest.delete_address') { @client.addresses.delete('addr-1') }
  end

  # ---- Lookup ---------------------------------------------------------

  def test_lookup_phone_number
    assert_kind_of Hash, @client.lookup.phone_number('+15551234567')
    assert_route('GET', "#{RELAY_BASE}/lookup/phone_number/+15551234567", 'relay-rest.lookup_phone_number')
  end

  def test_lookup_phone_number_error
    assert_error('relay-rest.lookup_phone_number') { @client.lookup.phone_number('+15551234567') }
  end
end

# Verified callers (CRUD + verification flow).
class RelayCoverageVerifiedCallersMockTest < Minitest::Test
  include RelayCoverageHelpers

  def test_verified_callers_list
    assert_kind_of Hash, @client.verified_callers.list
    assert_route('GET', "#{RELAY_BASE}/verified_caller_ids", 'relay-rest.list_verified_caller_ids')
  end

  def test_verified_callers_list_error
    assert_error('relay-rest.list_verified_caller_ids') { @client.verified_callers.list }
  end

  def test_verified_callers_create
    assert_kind_of Hash, @client.verified_callers.create(number: '+15551112222')
    last = assert_route('POST', "#{RELAY_BASE}/verified_caller_ids", 'relay-rest.create_verified_caller_id')
    assert_sent_body(last, 'number' => '+15551112222')
  end

  def test_verified_callers_create_error
    assert_error('relay-rest.create_verified_caller_id') { @client.verified_callers.create(number: '+1') }
  end

  def test_verified_callers_get
    assert_kind_of Hash, @client.verified_callers.get('vc-1')
    assert_route('GET', "#{RELAY_BASE}/verified_caller_ids/vc-1", 'relay-rest.retrieve_verified_caller_id')
  end

  def test_verified_callers_get_error
    assert_error('relay-rest.retrieve_verified_caller_id') { @client.verified_callers.get('vc-1') }
  end

  def test_verified_callers_update_uses_put
    assert_kind_of Hash, @client.verified_callers.update('vc-1', name: 'Reception')
    last = assert_route('PUT', "#{RELAY_BASE}/verified_caller_ids/vc-1", 'relay-rest.update_verified_caller_id')
    assert_sent_body(last, 'name' => 'Reception')
  end

  def test_verified_callers_update_error
    assert_error('relay-rest.update_verified_caller_id') { @client.verified_callers.update('vc-1', name: 'x') }
  end

  def test_verified_callers_delete
    assert_kind_of Hash, @client.verified_callers.delete('vc-1')
    assert_route('DELETE', "#{RELAY_BASE}/verified_caller_ids/vc-1", 'relay-rest.delete_verified_caller_id')
  end

  def test_verified_callers_delete_error
    assert_error('relay-rest.delete_verified_caller_id') { @client.verified_callers.delete('vc-1') }
  end

  def test_verified_callers_redial_verification
    assert_kind_of Hash, @client.verified_callers.redial_verification('vc-1')
    assert_route('POST', "#{RELAY_BASE}/verified_caller_ids/vc-1/verification",
                 'relay-rest.redial_verification_call')
  end

  def test_verified_callers_redial_verification_error
    assert_error('relay-rest.redial_verification_call') { @client.verified_callers.redial_verification('vc-1') }
  end

  def test_verified_callers_submit_verification_uses_put
    assert_kind_of Hash, @client.verified_callers.submit_verification('vc-1', verification_code: '123456')
    last = assert_route('PUT', "#{RELAY_BASE}/verified_caller_ids/vc-1/verification",
                        'relay-rest.validate_verification_code')
    assert_sent_body(last, 'verification_code' => '123456')
  end

  def test_verified_callers_submit_verification_error
    assert_error('relay-rest.validate_verification_code') do
      @client.verified_callers.submit_verification('vc-1', verification_code: '000000')
    end
  end
end

# Queues (+ members).
class RelayCoverageQueuesMockTest < Minitest::Test
  include RelayCoverageHelpers

  # ---- Queues ---------------------------------------------------------

  def test_queues_list
    assert_kind_of Hash, @client.queues.list
    assert_route('GET', "#{RELAY_BASE}/queues", 'relay-rest.list_queues')
  end

  def test_queues_list_error
    assert_error('relay-rest.list_queues') { @client.queues.list }
  end

  def test_queues_create
    assert_kind_of Hash, @client.queues.create(name: 'Support')
    last = assert_route('POST', "#{RELAY_BASE}/queues", 'relay-rest.create_queue')
    assert_sent_body(last, 'name' => 'Support')
  end

  def test_queues_create_error
    assert_error('relay-rest.create_queue') { @client.queues.create(name: 'x') }
  end

  def test_queues_get
    assert_kind_of Hash, @client.queues.get('q-1')
    assert_route('GET', "#{RELAY_BASE}/queues/q-1", 'relay-rest.get_queue')
  end

  def test_queues_get_error
    assert_error('relay-rest.get_queue') { @client.queues.get('q-1') }
  end

  def test_queues_update_uses_put
    assert_kind_of Hash, @client.queues.update('q-1', name: 'Renamed')
    last = assert_route('PUT', "#{RELAY_BASE}/queues/q-1", 'relay-rest.update_queue')
    assert_sent_body(last, 'name' => 'Renamed')
  end

  def test_queues_update_error
    assert_error('relay-rest.update_queue') { @client.queues.update('q-1', name: 'x') }
  end

  def test_queues_delete
    assert_kind_of Hash, @client.queues.delete('q-1')
    assert_route('DELETE', "#{RELAY_BASE}/queues/q-1", 'relay-rest.delete_queue')
  end

  def test_queues_delete_error
    assert_error('relay-rest.delete_queue') { @client.queues.delete('q-1') }
  end

  def test_queues_list_members
    assert_kind_of Hash, @client.queues.list_members('q-1')
    assert_route('GET', "#{RELAY_BASE}/queues/q-1/members", 'relay-rest.list_queue_members')
  end

  def test_queues_list_members_error
    assert_error('relay-rest.list_queue_members') { @client.queues.list_members('q-1') }
  end

  def test_queues_get_next_member
    assert_kind_of Hash, @client.queues.get_next_member('q-1')
    assert_route('GET', "#{RELAY_BASE}/queues/q-1/members/next", 'relay-rest.retrieve_next_queue_member')
  end

  def test_queues_get_next_member_error
    assert_error('relay-rest.retrieve_next_queue_member') { @client.queues.get_next_member('q-1') }
  end

  def test_queues_get_member
    assert_kind_of Hash, @client.queues.get_member('q-1', 'mem-1')
    assert_route('GET', "#{RELAY_BASE}/queues/q-1/members/mem-1", 'relay-rest.retrieve_queue_member')
  end

  def test_queues_get_member_error
    assert_error('relay-rest.retrieve_queue_member') { @client.queues.get_member('q-1', 'mem-1') }
  end
end

# Recordings.
class RelayCoverageRecordingsMockTest < Minitest::Test
  include RelayCoverageHelpers

  # ---- Recordings -----------------------------------------------------

  def test_recordings_list
    assert_kind_of Hash, @client.recordings.list
    assert_route('GET', "#{RELAY_BASE}/recordings", 'relay-rest.list_recordings')
  end

  def test_recordings_list_error
    assert_error('relay-rest.list_recordings') { @client.recordings.list }
  end

  def test_recordings_get
    assert_kind_of Hash, @client.recordings.get('rec-1')
    assert_route('GET', "#{RELAY_BASE}/recordings/rec-1", 'relay-rest.get_recording')
  end

  def test_recordings_get_error
    assert_error('relay-rest.get_recording') { @client.recordings.get('rec-1') }
  end

  def test_recordings_delete
    assert_kind_of Hash, @client.recordings.delete('rec-1')
    assert_route('DELETE', "#{RELAY_BASE}/recordings/rec-1", 'relay-rest.delete_recording')
  end

  def test_recordings_delete_error
    assert_error('relay-rest.delete_recording') { @client.recordings.delete('rec-1') }
  end
end

# Number groups (+ memberships).
class RelayCoverageNumberGroupsMockTest < Minitest::Test
  include RelayCoverageHelpers

  # ---- Number groups (+ memberships) ----------------------------------

  def test_number_groups_list
    assert_kind_of Hash, @client.number_groups.list
    assert_route('GET', "#{RELAY_BASE}/number_groups", 'relay-rest.list_number_groups')
  end

  def test_number_groups_list_error
    assert_error('relay-rest.list_number_groups') { @client.number_groups.list }
  end

  def test_number_groups_create
    assert_kind_of Hash, @client.number_groups.create(name: 'Sales')
    last = assert_route('POST', "#{RELAY_BASE}/number_groups", 'relay-rest.create_number_group')
    assert_sent_body(last, 'name' => 'Sales')
  end

  def test_number_groups_create_error
    assert_error('relay-rest.create_number_group') { @client.number_groups.create(name: 'x') }
  end

  def test_number_groups_get
    assert_kind_of Hash, @client.number_groups.get('ng-1')
    assert_route('GET', "#{RELAY_BASE}/number_groups/ng-1", 'relay-rest.retrieve_number_group')
  end

  def test_number_groups_get_error
    assert_error('relay-rest.retrieve_number_group') { @client.number_groups.get('ng-1') }
  end

  def test_number_groups_update_uses_put
    assert_kind_of Hash, @client.number_groups.update('ng-1', name: 'Renamed')
    last = assert_route('PUT', "#{RELAY_BASE}/number_groups/ng-1", 'relay-rest.update_number_group')
    assert_sent_body(last, 'name' => 'Renamed')
  end

  def test_number_groups_update_error
    assert_error('relay-rest.update_number_group') { @client.number_groups.update('ng-1', name: 'x') }
  end

  def test_number_groups_delete
    assert_kind_of Hash, @client.number_groups.delete('ng-1')
    assert_route('DELETE', "#{RELAY_BASE}/number_groups/ng-1", 'relay-rest.delete_number_group')
  end

  def test_number_groups_delete_error
    assert_error('relay-rest.delete_number_group') { @client.number_groups.delete('ng-1') }
  end

  def test_number_groups_list_memberships
    assert_kind_of Hash, @client.number_groups.list_memberships('ng-1')
    assert_route('GET', "#{RELAY_BASE}/number_groups/ng-1/number_group_memberships",
                 'relay-rest.list_number_group_memberships')
  end

  def test_number_groups_list_memberships_error
    assert_error('relay-rest.list_number_group_memberships') { @client.number_groups.list_memberships('ng-1') }
  end

  def test_number_groups_add_membership
    assert_kind_of Hash, @client.number_groups.add_membership('ng-1', phone_number_id: 'pn-1')
    last = assert_route('POST', "#{RELAY_BASE}/number_groups/ng-1/number_group_memberships",
                        'relay-rest.create_number_group_membership')
    assert_sent_body(last, 'phone_number_id' => 'pn-1')
  end

  def test_number_groups_add_membership_error
    assert_error('relay-rest.create_number_group_membership') do
      @client.number_groups.add_membership('ng-1', phone_number_id: 'pn-1')
    end
  end

  def test_number_groups_get_membership
    assert_kind_of Hash, @client.number_groups.get_membership('mem-1')
    assert_route('GET', "#{RELAY_BASE}/number_group_memberships/mem-1",
                 'relay-rest.retrieve_number_group_membership')
  end

  def test_number_groups_get_membership_error
    assert_error('relay-rest.retrieve_number_group_membership') { @client.number_groups.get_membership('mem-1') }
  end

  def test_number_groups_delete_membership
    assert_kind_of Hash, @client.number_groups.delete_membership('mem-1')
    assert_route('DELETE', "#{RELAY_BASE}/number_group_memberships/mem-1",
                 'relay-rest.delete_number_group_membership')
  end

  def test_number_groups_delete_membership_error
    assert_error('relay-rest.delete_number_group_membership') { @client.number_groups.delete_membership('mem-1') }
  end
end

# Short codes + imported numbers + MFA + SIP profile.
class RelayCoverageMiscMockTest < Minitest::Test
  include RelayCoverageHelpers

  # ---- Short codes ----------------------------------------------------

  def test_short_codes_list
    assert_kind_of Hash, @client.short_codes.list
    assert_route('GET', "#{RELAY_BASE}/short_codes", 'relay-rest.list_short_codes')
  end

  def test_short_codes_list_error
    assert_error('relay-rest.list_short_codes') { @client.short_codes.list }
  end

  def test_short_codes_get
    assert_kind_of Hash, @client.short_codes.get('sc-1')
    assert_route('GET', "#{RELAY_BASE}/short_codes/sc-1", 'relay-rest.retrieve_short_code')
  end

  def test_short_codes_get_error
    assert_error('relay-rest.retrieve_short_code') { @client.short_codes.get('sc-1') }
  end

  def test_short_codes_update_uses_put
    assert_kind_of Hash, @client.short_codes.update('sc-1', name: 'Promo')
    last = assert_route('PUT', "#{RELAY_BASE}/short_codes/sc-1", 'relay-rest.update_short_code')
    assert_sent_body(last, 'name' => 'Promo')
  end

  def test_short_codes_update_error
    assert_error('relay-rest.update_short_code') { @client.short_codes.update('sc-1', name: 'x') }
  end

  # ---- Imported numbers -----------------------------------------------

  def test_imported_numbers_create
    assert_kind_of Hash, @client.imported_numbers.create(number: '+15551234567', sip_username: 'alice')
    last = assert_route('POST', "#{RELAY_BASE}/imported_phone_numbers", 'relay-rest.create_imported_phone_number')
    assert_sent_body(last, 'number' => '+15551234567', 'sip_username' => 'alice')
  end

  def test_imported_numbers_create_error
    assert_error('relay-rest.create_imported_phone_number') { @client.imported_numbers.create(number: '+1') }
  end

  # ---- MFA ------------------------------------------------------------

  def test_mfa_call
    assert_kind_of Hash, @client.mfa.call(to: '+15551234567', from_: '+15559876543')
    last = assert_route('POST', "#{RELAY_BASE}/mfa/call", 'relay-rest.request_mfa_call')
    assert_sent_body(last, 'to' => '+15551234567', 'from_' => '+15559876543')
  end

  def test_mfa_call_error
    assert_error('relay-rest.request_mfa_call') { @client.mfa.call(to: '+1') }
  end

  def test_mfa_sms
    assert_kind_of Hash, @client.mfa.sms(to: '+15551234567', from_: '+15559876543')
    last = assert_route('POST', "#{RELAY_BASE}/mfa/sms", 'relay-rest.request_mfa_sms')
    assert_sent_body(last, 'to' => '+15551234567')
  end

  def test_mfa_sms_error
    assert_error('relay-rest.request_mfa_sms') { @client.mfa.sms(to: '+1') }
  end

  def test_mfa_verify
    assert_kind_of Hash, @client.mfa.verify('req-1', token: '123456')
    last = assert_route('POST', "#{RELAY_BASE}/mfa/req-1/verify", 'relay-rest.verify_mfa_token')
    assert_sent_body(last, 'token' => '123456')
  end

  def test_mfa_verify_error
    assert_error('relay-rest.verify_mfa_token') { @client.mfa.verify('req-1', token: '000000') }
  end

  # ---- SIP profile (singleton) ----------------------------------------

  def test_sip_profile_get
    assert_kind_of Hash, @client.sip_profile.get
    assert_route('GET', "#{RELAY_BASE}/sip_profile", 'relay-rest.retrieve_sip_profile')
  end

  def test_sip_profile_get_error
    assert_error('relay-rest.retrieve_sip_profile') { @client.sip_profile.get }
  end

  def test_sip_profile_update_uses_put
    assert_kind_of Hash, @client.sip_profile.update(domain: 'myco.sip.signalwire.com')
    last = assert_route('PUT', "#{RELAY_BASE}/sip_profile", 'relay-rest.update_sip_profile')
    assert_sent_body(last, 'domain' => 'myco.sip.signalwire.com')
  end

  def test_sip_profile_update_error
    assert_error('relay-rest.update_sip_profile') { @client.sip_profile.update(domain: 'x') }
  end
end

# 10DLC Campaign Registry (brands, campaigns, orders, numbers).
class RelayCoverageRegistryMockTest < Minitest::Test
  include RelayCoverageHelpers

  REG_BASE = '/api/relay/rest/registry/beta'

  # ---- Brands ---------------------------------------------------------

  def test_brands_list
    assert_kind_of Hash, @client.registry.brands.list
    assert_route('GET', "#{REG_BASE}/brands", 'relay-rest.list_brands')
  end

  def test_brands_list_error
    assert_error('relay-rest.list_brands') { @client.registry.brands.list }
  end

  def test_brands_create
    assert_kind_of Hash, @client.registry.brands.create(entity_type: 'PRIVATE_PROFIT')
    last = assert_route('POST', "#{REG_BASE}/brands", 'relay-rest.create_brand')
    assert_sent_body(last, 'entity_type' => 'PRIVATE_PROFIT')
  end

  def test_brands_create_error
    assert_error('relay-rest.create_brand') { @client.registry.brands.create(entity_type: 'x') }
  end

  def test_brands_get
    assert_kind_of Hash, @client.registry.brands.get('brand-1')
    assert_route('GET', "#{REG_BASE}/brands/brand-1", 'relay-rest.retrieve_brand')
  end

  def test_brands_get_error
    assert_error('relay-rest.retrieve_brand') { @client.registry.brands.get('brand-1') }
  end

  def test_brands_list_campaigns
    assert_kind_of Hash, @client.registry.brands.list_campaigns('brand-1')
    assert_route('GET', "#{REG_BASE}/brands/brand-1/campaigns", 'relay-rest.list_campaigns')
  end

  def test_brands_list_campaigns_error
    assert_error('relay-rest.list_campaigns') { @client.registry.brands.list_campaigns('brand-1') }
  end

  def test_brands_create_campaign
    assert_kind_of Hash, @client.registry.brands.create_campaign('brand-1', usecase: 'LOW_VOLUME')
    last = assert_route('POST', "#{REG_BASE}/brands/brand-1/campaigns", 'relay-rest.create_campaign')
    assert_sent_body(last, 'usecase' => 'LOW_VOLUME')
  end

  def test_brands_create_campaign_error
    assert_error('relay-rest.create_campaign') { @client.registry.brands.create_campaign('brand-1', usecase: 'x') }
  end

  # ---- Campaigns ------------------------------------------------------

  def test_campaigns_get
    assert_kind_of Hash, @client.registry.campaigns.get('camp-1')
    assert_route('GET', "#{REG_BASE}/campaigns/camp-1", 'relay-rest.retrieve_campaign')
  end

  def test_campaigns_get_error
    assert_error('relay-rest.retrieve_campaign') { @client.registry.campaigns.get('camp-1') }
  end

  def test_campaigns_update_uses_put
    assert_kind_of Hash, @client.registry.campaigns.update('camp-1', description: 'Updated')
    last = assert_route('PUT', "#{REG_BASE}/campaigns/camp-1", 'relay-rest.update_campaign')
    assert_sent_body(last, 'description' => 'Updated')
  end

  def test_campaigns_update_error
    assert_error('relay-rest.update_campaign') { @client.registry.campaigns.update('camp-1', description: 'x') }
  end

  def test_campaigns_list_numbers
    assert_kind_of Hash, @client.registry.campaigns.list_numbers('camp-1')
    assert_route('GET', "#{REG_BASE}/campaigns/camp-1/numbers", 'relay-rest.list_number_assignments')
  end

  def test_campaigns_list_numbers_error
    assert_error('relay-rest.list_number_assignments') { @client.registry.campaigns.list_numbers('camp-1') }
  end

  def test_campaigns_list_orders
    assert_kind_of Hash, @client.registry.campaigns.list_orders('camp-1')
    assert_route('GET', "#{REG_BASE}/campaigns/camp-1/orders", 'relay-rest.list_orders')
  end

  def test_campaigns_list_orders_error
    assert_error('relay-rest.list_orders') { @client.registry.campaigns.list_orders('camp-1') }
  end

  def test_campaigns_create_order
    assert_kind_of Hash, @client.registry.campaigns.create_order('camp-1', numbers: %w[pn-1])
    last = assert_route('POST', "#{REG_BASE}/campaigns/camp-1/orders", 'relay-rest.create_order')
    assert_sent_body(last, 'numbers' => %w[pn-1])
  end

  def test_campaigns_create_order_error
    assert_error('relay-rest.create_order') { @client.registry.campaigns.create_order('camp-1', numbers: %w[pn-1]) }
  end

  # ---- Orders ---------------------------------------------------------

  def test_orders_get
    assert_kind_of Hash, @client.registry.orders.get('order-1')
    assert_route('GET', "#{REG_BASE}/orders/order-1", 'relay-rest.retrieve_order')
  end

  def test_orders_get_error
    assert_error('relay-rest.retrieve_order') { @client.registry.orders.get('order-1') }
  end

  # ---- Numbers --------------------------------------------------------

  def test_numbers_delete
    assert_kind_of Hash, @client.registry.numbers.delete('num-1')
    assert_route('DELETE', "#{REG_BASE}/numbers/num-1", 'relay-rest.delete_number_assignment')
  end

  def test_numbers_delete_error
    assert_error('relay-rest.delete_number_assignment') { @client.registry.numbers.delete('num-1') }
  end
end
