# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_phone_numbers.py.
#
# Covers the 8 uncovered CompatPhoneNumbers symbols:
#
#   - list, get, update, delete (basic CRUD over IncomingPhoneNumbers)
#   - purchase, import_number (phone-number provisioning)
#   - list_available_countries, search_toll_free

require 'minitest/autorun'
require_relative 'mock_test'

class CompatPhoneNumbersMockTest < Minitest::Test
  ACCOUNT_BASE = '/api/laml/2010-04-01/Accounts/test_proj'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- list -------------------------------------------------------------

  def test_list_returns_paginated_list
    result = @client.compat.phone_numbers.list

    assert_kind_of Hash, result
    assert(result.key?('incoming_phone_numbers'),
           "expected 'incoming_phone_numbers' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['incoming_phone_numbers']
  end

  def test_list_journal_records_get_to_incoming_phone_numbers
    @client.compat.phone_numbers.list
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{ACCOUNT_BASE}/IncomingPhoneNumbers", j.path
  end

  # ---- get --------------------------------------------------------------

  def test_get_returns_phone_number_resource
    result = @client.compat.phone_numbers.get('PN_TEST')

    assert_kind_of Hash, result
    assert(result.key?('phone_number') || result.key?('sid'),
           "expected phone_number/sid, got #{result.keys.sort.inspect}")
  end

  def test_get_journal_records_get_with_sid
    @client.compat.phone_numbers.get('PN_GET')
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{ACCOUNT_BASE}/IncomingPhoneNumbers/PN_GET", j.path
  end

  # ---- update -----------------------------------------------------------

  def test_update_returns_phone_number_resource
    result = @client.compat.phone_numbers.update('PN_U', FriendlyName: 'updated')

    assert_kind_of Hash, result
    assert(result.key?('phone_number') || result.key?('sid'),
           "expected phone_number/sid, got #{result.keys.sort.inspect}")
  end

  def test_update_journal_records_post_with_friendly_name
    @client.compat.phone_numbers.update('PN_UU', FriendlyName: 'updated', VoiceUrl: 'https://a.b/v')
    j = MockTest.journal.last
    body = j.body

    assert_equal 'POST', j.method
    assert_equal "#{ACCOUNT_BASE}/IncomingPhoneNumbers/PN_UU", j.path
    assert_kind_of Hash, body
    assert_equal 'updated', body['FriendlyName']
    assert_equal 'https://a.b/v', body['VoiceUrl']
  end

  # ---- delete -----------------------------------------------------------

  def test_delete_no_exception_on_delete
    result = @client.compat.phone_numbers.delete('PN_D')

    assert_kind_of Hash, result
  end

  def test_delete_journal_records_delete_at_phone_number_path
    @client.compat.phone_numbers.delete('PN_DEL')
    j = MockTest.journal.last

    assert_equal 'DELETE', j.method
    assert_equal "#{ACCOUNT_BASE}/IncomingPhoneNumbers/PN_DEL", j.path
  end
end

# Provisioning + availability: purchase / import_number / countries / toll-free.
class CompatPhoneNumbersProvisioningMockTest < Minitest::Test
  ACCOUNT_BASE = '/api/laml/2010-04-01/Accounts/test_proj'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- purchase (POST /IncomingPhoneNumbers) ---------------------------

  def test_purchase_returns_purchased_number
    result = @client.compat.phone_numbers.purchase(PhoneNumber: '+15555550100')

    assert_kind_of Hash, result
    assert(result.key?('phone_number') || result.key?('sid'),
           "expected phone_number/sid, got #{result.keys.sort.inspect}")
  end

  def test_purchase_journal_records_post_with_phone_number
    @client.compat.phone_numbers.purchase(PhoneNumber: '+15555550100', FriendlyName: 'Main')
    j = MockTest.journal.last
    body = j.body

    assert_equal 'POST', j.method
    assert_equal "#{ACCOUNT_BASE}/IncomingPhoneNumbers", j.path
    assert_kind_of Hash, body
    assert_equal '+15555550100', body['PhoneNumber']
    assert_equal 'Main', body['FriendlyName']
  end

  # ---- import_number (POST /ImportedPhoneNumbers) ----------------------

  def test_import_number_returns_imported_number
    result = @client.compat.phone_numbers.import_number(PhoneNumber: '+15555550111')

    assert_kind_of Hash, result
    assert(result.key?('phone_number') || result.key?('sid'),
           "expected phone_number/sid, got #{result.keys.sort.inspect}")
  end

  def test_import_number_journal_records_post_to_imported_phone_numbers
    @client.compat.phone_numbers.import_number(
      PhoneNumber: '+15555550111', VoiceUrl: 'https://a.b/v'
    )
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    # Note the path is ImportedPhoneNumbers, not IncomingPhoneNumbers.
    assert_equal "#{ACCOUNT_BASE}/ImportedPhoneNumbers", j.path
    assert_kind_of Hash, j.body
    assert_equal '+15555550111', j.body['PhoneNumber']
  end

  # ---- list_available_countries (GET /AvailablePhoneNumbers) ----------

  def test_list_available_countries_returns_countries_collection
    result = @client.compat.phone_numbers.list_available_countries

    assert_kind_of Hash, result
    assert(result.key?('countries'),
           "expected 'countries' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['countries']
  end

  def test_list_available_countries_journal_records_get
    @client.compat.phone_numbers.list_available_countries
    j = MockTest.journal.last

    assert_equal 'GET', j.method
    assert_equal "#{ACCOUNT_BASE}/AvailablePhoneNumbers", j.path
  end

  # ---- search_toll_free (GET /AvailablePhoneNumbers/{c}/TollFree) -----

  def test_search_toll_free_returns_available_numbers
    result = @client.compat.phone_numbers.search_toll_free('US', AreaCode: '800')

    assert_kind_of Hash, result
    assert(result.key?('available_phone_numbers'),
           "expected 'available_phone_numbers' key, got #{result.keys.sort.inspect}")
    assert_kind_of Array, result['available_phone_numbers']
  end

  def test_search_toll_free_journal_records_get_with_country_in_path
    @client.compat.phone_numbers.search_toll_free('US', AreaCode: '888')
    j = MockTest.journal.last
    query = j.query_params

    assert_equal 'GET', j.method
    assert_equal "#{ACCOUNT_BASE}/AvailablePhoneNumbers/US/TollFree", j.path
    # The AreaCode should be on the query string, not body.
    assert(query.key?('AreaCode'), "expected AreaCode in query params, got #{query.keys.inspect}")
    assert_equal ['888'], query['AreaCode']
  end
end
