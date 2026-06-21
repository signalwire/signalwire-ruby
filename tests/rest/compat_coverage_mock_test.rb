# frozen_string_literal: true

# Full REST success+error coverage for the +compatibility+ (LaML) spec group.
#
# Every canonical route in the compatibility OpenAPI spec that the Ruby SDK
# reaches gets a SUCCESS test (real +client.compat.*+ call: body shape + the
# journalled method / exact LaML path / +matched_route == endpoint_id+) AND an
# ERROR test (a +push_scenario+ override making the mock answer non-2xx, then
# +assert_raises(SignalWire::REST::SignalWireRestError)+ with the status_code).
# Together they satisfy mock_signalwire.rest_coverage's success+error bar.
#
# LaML paths embed the AccountSid: the compat namespace is wired with the
# per-client random project, so every path is asserted against
# +/api/laml/2010-04-01/Accounts/<@project>/...+ read from the harness, never a
# hard-coded sid.
#
# One accepted gap (matching the Python reference + per-port allowlist):
#   - compatibility.list_available_phone_number_resources_by_country
#     (no SDK method; the AvailablePhoneNumbers/{IsoCountry} index is not
#     surfaced — covered only by its Local / TollFree sub-searches).

require 'minitest/autorun'
require_relative 'mock_test'

# One distinct coverage class per the build spec; its length is the 78-route
# success+error surface, not avoidable complexity (same SIZE-not-correctness
# rationale the .rubocop.yml records for the parity-bearing lib classes).
# rubocop:disable Metrics/ClassLength
class CompatCoverageMockTest < Minitest::Test
  # Parallelize: per-client unique-project + auth-scoped harness isolates each
  # test, so the shared mock stays concurrency-safe.
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

  # Assert the last journalled request's method, exact path, and matched_route.
  def assert_journal(method, path, route)
    last = @mock.last

    assert_equal method, last.method
    assert_equal path, last.path
    assert_equal route, last.matched_route
    last
  end

  # Stage a non-2xx override for +route+, run +blk+, assert it raises
  # SignalWireRestError carrying +status+, and that the wire hit +route+.
  def assert_error(route, status, method, path, &)
    @mock.push_scenario(route, status: status, response: { 'error' => 'boom' })
    err = assert_raises(SignalWire::REST::SignalWireRestError, &)

    assert_equal status, err.status_code
    last = @mock.last

    assert_equal status, last.response_status
    assert_equal method, last.method
    assert_equal path, last.path
    assert_equal route, last.matched_route
  end

  # ===================================================================
  # Accounts / subprojects
  # ===================================================================

  def test_list_accounts_success
    body = @client.compat.accounts.list

    assert_kind_of Hash, body
    assert_journal('GET', '/api/laml/2010-04-01/Accounts', 'compatibility.list_accounts')
  end

  def test_list_accounts_error
    assert_error('compatibility.list_accounts', 500, 'GET',
                 '/api/laml/2010-04-01/Accounts') { @client.compat.accounts.list }
  end

  def test_create_subprojects_success
    body = @client.compat.accounts.create(FriendlyName: 'Sub-A')

    assert_kind_of Hash, body
    j = assert_journal('POST', '/api/laml/2010-04-01/Accounts', 'compatibility.create_subprojects')

    assert_equal 'Sub-A', j.body['FriendlyName']
  end

  def test_create_subprojects_error
    assert_error('compatibility.create_subprojects', 422, 'POST',
                 '/api/laml/2010-04-01/Accounts') do
      @client.compat.accounts.create(FriendlyName: 'x')
    end
  end

  def test_get_account_success
    body = @client.compat.accounts.get('AC123')

    assert_kind_of Hash, body
    assert_journal('GET', '/api/laml/2010-04-01/Accounts/AC123', 'compatibility.get_account')
  end

  def test_get_account_error
    assert_error('compatibility.get_account', 404, 'GET',
                 '/api/laml/2010-04-01/Accounts/missing') { @client.compat.accounts.get('missing') }
  end

  def test_update_account_success
    body = @client.compat.accounts.update('AC123', FriendlyName: 'Renamed')

    assert_kind_of Hash, body
    j = assert_journal('POST', '/api/laml/2010-04-01/Accounts/AC123', 'compatibility.update_account')

    assert_equal 'Renamed', j.body['FriendlyName']
  end

  def test_update_account_error
    assert_error('compatibility.update_account', 404, 'POST',
                 '/api/laml/2010-04-01/Accounts/missing') do
      @client.compat.accounts.update('missing', FriendlyName: 'x')
    end
  end

  # ===================================================================
  # Calls (+ recordings / streams sub-resources)
  # ===================================================================

  def test_list_all_calls_success
    body = @client.compat.calls.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Calls", 'compatibility.list_all_calls')
  end

  def test_list_all_calls_error
    assert_error('compatibility.list_all_calls', 500, 'GET',
                 "#{account_base}/Calls") { @client.compat.calls.list }
  end

  def test_create_a_call_success
    body = @client.compat.calls.create(To: '+15551112222', From: '+15553334444', Url: 'https://x/y')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Calls", 'compatibility.create_a_call')

    assert_equal '+15551112222', j.body['To']
  end

  def test_create_a_call_error
    assert_error('compatibility.create_a_call', 422, 'POST', "#{account_base}/Calls") do
      @client.compat.calls.create(To: 'x')
    end
  end

  def test_retrieve_a_call_success
    body = @client.compat.calls.get('CA1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Calls/CA1", 'compatibility.retrieve_a_call')
  end

  def test_retrieve_a_call_error
    assert_error('compatibility.retrieve_a_call', 404, 'GET',
                 "#{account_base}/Calls/missing") { @client.compat.calls.get('missing') }
  end

  def test_update_a_call_success
    body = @client.compat.calls.update('CA1', Status: 'completed')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Calls/CA1", 'compatibility.update_a_call')

    assert_equal 'completed', j.body['Status']
  end

  def test_update_a_call_error
    assert_error('compatibility.update_a_call', 404, 'POST', "#{account_base}/Calls/missing") do
      @client.compat.calls.update('missing', Status: 'completed')
    end
  end

  def test_delete_a_call_success
    @client.compat.calls.delete('CA1')

    assert_journal('DELETE', "#{account_base}/Calls/CA1", 'compatibility.delete_a_call')
  end

  def test_delete_a_call_error
    assert_error('compatibility.delete_a_call', 404, 'DELETE',
                 "#{account_base}/Calls/missing") { @client.compat.calls.delete('missing') }
  end

  def test_create_recording_success
    body = @client.compat.calls.start_recording('CA1')

    assert_kind_of Hash, body
    assert_journal('POST', "#{account_base}/Calls/CA1/Recordings", 'compatibility.create_recording')
  end

  def test_create_recording_error
    assert_error('compatibility.create_recording', 404, 'POST',
                 "#{account_base}/Calls/missing/Recordings") do
      @client.compat.calls.start_recording('missing')
    end
  end

  def test_update_recording_success
    body = @client.compat.calls.update_recording('CA1', 'RE1', Status: 'paused')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Calls/CA1/Recordings/RE1",
                       'compatibility.update_recording')

    assert_equal 'paused', j.body['Status']
  end

  def test_update_recording_error
    assert_error('compatibility.update_recording', 404, 'POST',
                 "#{account_base}/Calls/CA1/Recordings/missing") do
      @client.compat.calls.update_recording('CA1', 'missing', Status: 'paused')
    end
  end

  def test_create_stream_success
    body = @client.compat.calls.start_stream('CA1', Url: 'wss://a.b/s', Name: 'strm')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Calls/CA1/Streams", 'compatibility.create_stream')

    assert_equal 'wss://a.b/s', j.body['Url']
  end

  def test_create_stream_error
    assert_error('compatibility.create_stream', 404, 'POST',
                 "#{account_base}/Calls/missing/Streams") do
      @client.compat.calls.start_stream('missing', Url: 'wss://a.b/s')
    end
  end

  def test_update_stream_success
    body = @client.compat.calls.stop_stream('CA1', 'ST1', Status: 'stopped')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Calls/CA1/Streams/ST1", 'compatibility.update_stream')

    assert_equal 'stopped', j.body['Status']
  end

  def test_update_stream_error
    assert_error('compatibility.update_stream', 404, 'POST',
                 "#{account_base}/Calls/CA1/Streams/missing") do
      @client.compat.calls.stop_stream('CA1', 'missing', Status: 'stopped')
    end
  end

  # ===================================================================
  # Messages (+ media sub-resources)
  # ===================================================================

  def test_list_messages_success
    body = @client.compat.messages.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Messages", 'compatibility.list_messages')
  end

  def test_list_messages_error
    assert_error('compatibility.list_messages', 500, 'GET',
                 "#{account_base}/Messages") { @client.compat.messages.list }
  end

  def test_create_message_success
    body = @client.compat.messages.create(To: '+15551112222', From: '+15553334444', Body: 'hi')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Messages", 'compatibility.create_message')

    assert_equal 'hi', j.body['Body']
  end

  def test_create_message_error
    assert_error('compatibility.create_message', 422, 'POST', "#{account_base}/Messages") do
      @client.compat.messages.create(To: 'x')
    end
  end

  def test_retrieve_message_success
    body = @client.compat.messages.get('MM1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Messages/MM1", 'compatibility.retrieve_message')
  end

  def test_retrieve_message_error
    assert_error('compatibility.retrieve_message', 404, 'GET',
                 "#{account_base}/Messages/missing") { @client.compat.messages.get('missing') }
  end

  def test_update_message_success
    body = @client.compat.messages.update('MM1', Body: 'edited')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Messages/MM1", 'compatibility.update_message')

    assert_equal 'edited', j.body['Body']
  end

  def test_update_message_error
    assert_error('compatibility.update_message', 404, 'POST', "#{account_base}/Messages/missing") do
      @client.compat.messages.update('missing', Body: 'x')
    end
  end

  def test_delete_message_success
    @client.compat.messages.delete('MM1')

    assert_journal('DELETE', "#{account_base}/Messages/MM1", 'compatibility.delete_message')
  end

  def test_delete_message_error
    assert_error('compatibility.delete_message', 404, 'DELETE',
                 "#{account_base}/Messages/missing") { @client.compat.messages.delete('missing') }
  end

  def test_list_media_success
    body = @client.compat.messages.list_media('MM1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Messages/MM1/Media", 'compatibility.list_media')
  end

  def test_list_media_error
    assert_error('compatibility.list_media', 404, 'GET',
                 "#{account_base}/Messages/missing/Media") do
      @client.compat.messages.list_media('missing')
    end
  end

  def test_retrieve_media_success
    body = @client.compat.messages.get_media('MM1', 'ME1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Messages/MM1/Media/ME1", 'compatibility.retrieve_media')
  end

  def test_retrieve_media_error
    assert_error('compatibility.retrieve_media', 404, 'GET',
                 "#{account_base}/Messages/MM1/Media/missing") do
      @client.compat.messages.get_media('MM1', 'missing')
    end
  end

  def test_delete_message_media_success
    @client.compat.messages.delete_media('MM1', 'ME1')

    assert_journal('DELETE', "#{account_base}/Messages/MM1/Media/ME1",
                   'compatibility.delete_message_media')
  end

  def test_delete_message_media_error
    assert_error('compatibility.delete_message_media', 404, 'DELETE',
                 "#{account_base}/Messages/MM1/Media/missing") do
      @client.compat.messages.delete_media('MM1', 'missing')
    end
  end

  # ===================================================================
  # Faxes (+ media sub-resources)
  # ===================================================================

  def test_list_all_faxes_success
    body = @client.compat.faxes.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Faxes", 'compatibility.list_all_faxes')
  end

  def test_list_all_faxes_error
    assert_error('compatibility.list_all_faxes', 500, 'GET',
                 "#{account_base}/Faxes") { @client.compat.faxes.list }
  end

  def test_send_fax_success
    body = @client.compat.faxes.create(To: '+15551112222', MediaUrl: 'https://x/f.pdf')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Faxes", 'compatibility.send_fax')

    assert_equal '+15551112222', j.body['To']
  end

  def test_send_fax_error
    assert_error('compatibility.send_fax', 422, 'POST', "#{account_base}/Faxes") do
      @client.compat.faxes.create(To: 'x')
    end
  end

  def test_retrieve_fax_success
    body = @client.compat.faxes.get('FX1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Faxes/FX1", 'compatibility.retrieve_fax')
  end

  def test_retrieve_fax_error
    assert_error('compatibility.retrieve_fax', 404, 'GET',
                 "#{account_base}/Faxes/missing") { @client.compat.faxes.get('missing') }
  end

  def test_update_fax_success
    body = @client.compat.faxes.update('FX1', Status: 'canceled')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Faxes/FX1", 'compatibility.update_fax')

    assert_equal 'canceled', j.body['Status']
  end

  def test_update_fax_error
    assert_error('compatibility.update_fax', 404, 'POST', "#{account_base}/Faxes/missing") do
      @client.compat.faxes.update('missing', Status: 'canceled')
    end
  end

  def test_delete_fax_success
    @client.compat.faxes.delete('FX1')

    assert_journal('DELETE', "#{account_base}/Faxes/FX1", 'compatibility.delete_fax')
  end

  def test_delete_fax_error
    assert_error('compatibility.delete_fax', 404, 'DELETE',
                 "#{account_base}/Faxes/missing") { @client.compat.faxes.delete('missing') }
  end

  def test_list_all_fax_media_success
    body = @client.compat.faxes.list_media('FX1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Faxes/FX1/Media", 'compatibility.list_all_fax_media')
  end

  def test_list_all_fax_media_error
    assert_error('compatibility.list_all_fax_media', 404, 'GET',
                 "#{account_base}/Faxes/missing/Media") do
      @client.compat.faxes.list_media('missing')
    end
  end

  def test_retrieve_medias_success
    body = @client.compat.faxes.get_media('FX1', 'ME1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Faxes/FX1/Media/ME1", 'compatibility.retrieve_medias')
  end

  def test_retrieve_medias_error
    assert_error('compatibility.retrieve_medias', 404, 'GET',
                 "#{account_base}/Faxes/FX1/Media/missing") do
      @client.compat.faxes.get_media('FX1', 'missing')
    end
  end

  def test_delete_fax_media_success
    @client.compat.faxes.delete_media('FX1', 'ME1')

    assert_journal('DELETE', "#{account_base}/Faxes/FX1/Media/ME1", 'compatibility.delete_fax_media')
  end

  def test_delete_fax_media_error
    assert_error('compatibility.delete_fax_media', 404, 'DELETE',
                 "#{account_base}/Faxes/FX1/Media/missing") do
      @client.compat.faxes.delete_media('FX1', 'missing')
    end
  end

  # ===================================================================
  # Conferences (+ participants / recordings / streams)
  # ===================================================================

  def test_list_all_conferences_success
    body = @client.compat.conferences.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Conferences", 'compatibility.list_all_conferences')
  end

  def test_list_all_conferences_error
    assert_error('compatibility.list_all_conferences', 500, 'GET',
                 "#{account_base}/Conferences") { @client.compat.conferences.list }
  end

  def test_retrieve_conference_success
    body = @client.compat.conferences.get('CF1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Conferences/CF1", 'compatibility.retrieve_conference')
  end

  def test_retrieve_conference_error
    assert_error('compatibility.retrieve_conference', 404, 'GET',
                 "#{account_base}/Conferences/missing") { @client.compat.conferences.get('missing') }
  end

  def test_update_conference_success
    body = @client.compat.conferences.update('CF1', Status: 'completed')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Conferences/CF1", 'compatibility.update_conference')

    assert_equal 'completed', j.body['Status']
  end

  def test_update_conference_error
    assert_error('compatibility.update_conference', 404, 'POST',
                 "#{account_base}/Conferences/missing") do
      @client.compat.conferences.update('missing', Status: 'completed')
    end
  end

  def test_list_all_participants_success
    body = @client.compat.conferences.list_participants('CF1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Conferences/CF1/Participants",
                   'compatibility.list_all_participants')
  end

  def test_list_all_participants_error
    assert_error('compatibility.list_all_participants', 404, 'GET',
                 "#{account_base}/Conferences/missing/Participants") do
      @client.compat.conferences.list_participants('missing')
    end
  end

  def test_retrieve_participant_success
    body = @client.compat.conferences.get_participant('CF1', 'CA1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Conferences/CF1/Participants/CA1",
                   'compatibility.retrieve_participant')
  end

  def test_retrieve_participant_error
    assert_error('compatibility.retrieve_participant', 404, 'GET',
                 "#{account_base}/Conferences/CF1/Participants/missing") do
      @client.compat.conferences.get_participant('CF1', 'missing')
    end
  end

  def test_update_participant_success
    body = @client.compat.conferences.update_participant('CF1', 'CA1', Muted: 'true')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Conferences/CF1/Participants/CA1",
                       'compatibility.update_participant')

    assert_equal 'true', j.body['Muted']
  end

  def test_update_participant_error
    assert_error('compatibility.update_participant', 404, 'POST',
                 "#{account_base}/Conferences/CF1/Participants/missing") do
      @client.compat.conferences.update_participant('CF1', 'missing', Muted: 'true')
    end
  end

  def test_delete_participant_success
    @client.compat.conferences.remove_participant('CF1', 'CA1')

    assert_journal('DELETE', "#{account_base}/Conferences/CF1/Participants/CA1",
                   'compatibility.delete_participant')
  end

  def test_delete_participant_error
    assert_error('compatibility.delete_participant', 404, 'DELETE',
                 "#{account_base}/Conferences/CF1/Participants/missing") do
      @client.compat.conferences.remove_participant('CF1', 'missing')
    end
  end

  def test_list_conference_recordings_success
    body = @client.compat.conferences.list_recordings('CF1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Conferences/CF1/Recordings",
                   'compatibility.list_conference_recordings')
  end

  def test_list_conference_recordings_error
    assert_error('compatibility.list_conference_recordings', 404, 'GET',
                 "#{account_base}/Conferences/missing/Recordings") do
      @client.compat.conferences.list_recordings('missing')
    end
  end

  def test_get_conference_recording_success
    body = @client.compat.conferences.get_recording('CF1', 'RE1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Conferences/CF1/Recordings/RE1",
                   'compatibility.get_conference_recording')
  end

  def test_get_conference_recording_error
    assert_error('compatibility.get_conference_recording', 404, 'GET',
                 "#{account_base}/Conferences/CF1/Recordings/missing") do
      @client.compat.conferences.get_recording('CF1', 'missing')
    end
  end

  def test_update_conference_recording_success
    body = @client.compat.conferences.update_recording('CF1', 'RE1', Status: 'paused')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Conferences/CF1/Recordings/RE1",
                       'compatibility.update_conference_recording')

    assert_equal 'paused', j.body['Status']
  end

  def test_update_conference_recording_error
    assert_error('compatibility.update_conference_recording', 404, 'POST',
                 "#{account_base}/Conferences/CF1/Recordings/missing") do
      @client.compat.conferences.update_recording('CF1', 'missing', Status: 'paused')
    end
  end

  def test_delete_conference_recording_success
    @client.compat.conferences.delete_recording('CF1', 'RE1')

    assert_journal('DELETE', "#{account_base}/Conferences/CF1/Recordings/RE1",
                   'compatibility.delete_conference_recording')
  end

  def test_delete_conference_recording_error
    assert_error('compatibility.delete_conference_recording', 404, 'DELETE',
                 "#{account_base}/Conferences/CF1/Recordings/missing") do
      @client.compat.conferences.delete_recording('CF1', 'missing')
    end
  end

  def test_create_conference_stream_success
    body = @client.compat.conferences.start_stream('CF1', Url: 'wss://a.b/s')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Conferences/CF1/Streams",
                       'compatibility.create_conference_stream')

    assert_equal 'wss://a.b/s', j.body['Url']
  end

  def test_create_conference_stream_error
    assert_error('compatibility.create_conference_stream', 404, 'POST',
                 "#{account_base}/Conferences/missing/Streams") do
      @client.compat.conferences.start_stream('missing', Url: 'wss://a.b/s')
    end
  end

  def test_update_conference_stream_success
    body = @client.compat.conferences.stop_stream('CF1', 'ST1', Status: 'stopped')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Conferences/CF1/Streams/ST1",
                       'compatibility.update_conference_stream')

    assert_equal 'stopped', j.body['Status']
  end

  def test_update_conference_stream_error
    assert_error('compatibility.update_conference_stream', 404, 'POST',
                 "#{account_base}/Conferences/CF1/Streams/missing") do
      @client.compat.conferences.stop_stream('CF1', 'missing', Status: 'stopped')
    end
  end

  # ===================================================================
  # Phone numbers (incoming / imported / available searches)
  # ===================================================================

  def test_list_incoming_phone_numbers_success
    body = @client.compat.phone_numbers.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/IncomingPhoneNumbers",
                   'compatibility.list_incoming_phone_numbers')
  end

  def test_list_incoming_phone_numbers_error
    assert_error('compatibility.list_incoming_phone_numbers', 500, 'GET',
                 "#{account_base}/IncomingPhoneNumbers") { @client.compat.phone_numbers.list }
  end

  def test_create_incoming_phone_number_success
    body = @client.compat.phone_numbers.purchase(PhoneNumber: '+15551112222')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/IncomingPhoneNumbers",
                       'compatibility.create_incoming_phone_number')

    assert_equal '+15551112222', j.body['PhoneNumber']
  end

  def test_create_incoming_phone_number_error
    assert_error('compatibility.create_incoming_phone_number', 422, 'POST',
                 "#{account_base}/IncomingPhoneNumbers") do
      @client.compat.phone_numbers.purchase(PhoneNumber: '+1')
    end
  end

  def test_retrieve_incoming_phone_number_success
    body = @client.compat.phone_numbers.get('PN1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/IncomingPhoneNumbers/PN1",
                   'compatibility.retrieve_incoming_phone_number')
  end

  def test_retrieve_incoming_phone_number_error
    assert_error('compatibility.retrieve_incoming_phone_number', 404, 'GET',
                 "#{account_base}/IncomingPhoneNumbers/missing") do
      @client.compat.phone_numbers.get('missing')
    end
  end

  def test_update_incoming_phone_number_success
    body = @client.compat.phone_numbers.update('PN1', FriendlyName: 'renamed')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/IncomingPhoneNumbers/PN1",
                       'compatibility.update_incoming_phone_number')

    assert_equal 'renamed', j.body['FriendlyName']
  end

  def test_update_incoming_phone_number_error
    assert_error('compatibility.update_incoming_phone_number', 404, 'POST',
                 "#{account_base}/IncomingPhoneNumbers/missing") do
      @client.compat.phone_numbers.update('missing', FriendlyName: 'x')
    end
  end

  def test_delete_incoming_phone_number_success
    @client.compat.phone_numbers.delete('PN1')

    assert_journal('DELETE', "#{account_base}/IncomingPhoneNumbers/PN1",
                   'compatibility.delete_incoming_phone_number')
  end

  def test_delete_incoming_phone_number_error
    assert_error('compatibility.delete_incoming_phone_number', 404, 'DELETE',
                 "#{account_base}/IncomingPhoneNumbers/missing") do
      @client.compat.phone_numbers.delete('missing')
    end
  end

  def test_create_imported_phone_number_success
    body = @client.compat.phone_numbers.import_number(PhoneNumber: '+15551112222')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/ImportedPhoneNumbers",
                       'compatibility.create_imported_phone_number')

    assert_equal '+15551112222', j.body['PhoneNumber']
  end

  def test_create_imported_phone_number_error
    assert_error('compatibility.create_imported_phone_number', 422, 'POST',
                 "#{account_base}/ImportedPhoneNumbers") do
      @client.compat.phone_numbers.import_number(PhoneNumber: '+1')
    end
  end

  def test_list_available_phone_number_resources_success
    body = @client.compat.phone_numbers.list_available_countries

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/AvailablePhoneNumbers",
                   'compatibility.list_available_phone_number_resources')
  end

  def test_list_available_phone_number_resources_error
    assert_error('compatibility.list_available_phone_number_resources', 500, 'GET',
                 "#{account_base}/AvailablePhoneNumbers") do
      @client.compat.phone_numbers.list_available_countries
    end
  end

  def test_search_local_available_phone_numbers_success
    body = @client.compat.phone_numbers.search_local('US')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/AvailablePhoneNumbers/US/Local",
                   'compatibility.search_local_available_phone_numbers')
  end

  def test_search_local_available_phone_numbers_error
    assert_error('compatibility.search_local_available_phone_numbers', 500, 'GET',
                 "#{account_base}/AvailablePhoneNumbers/US/Local") do
      @client.compat.phone_numbers.search_local('US')
    end
  end

  def test_search_toll_free_available_phone_numbers_success
    body = @client.compat.phone_numbers.search_toll_free('US')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/AvailablePhoneNumbers/US/TollFree",
                   'compatibility.search_toll_free_available_phone_numbers')
  end

  def test_search_toll_free_available_phone_numbers_error
    assert_error('compatibility.search_toll_free_available_phone_numbers', 500, 'GET',
                 "#{account_base}/AvailablePhoneNumbers/US/TollFree") do
      @client.compat.phone_numbers.search_toll_free('US')
    end
  end

  # ===================================================================
  # Applications
  # ===================================================================

  def test_list_applications_success
    body = @client.compat.applications.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Applications", 'compatibility.list_applications')
  end

  def test_list_applications_error
    assert_error('compatibility.list_applications', 500, 'GET',
                 "#{account_base}/Applications") { @client.compat.applications.list }
  end

  def test_create_application_success
    body = @client.compat.applications.create(FriendlyName: 'App-A')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Applications", 'compatibility.create_application')

    assert_equal 'App-A', j.body['FriendlyName']
  end

  def test_create_application_error
    assert_error('compatibility.create_application', 422, 'POST', "#{account_base}/Applications") do
      @client.compat.applications.create(FriendlyName: 'x')
    end
  end

  def test_get_application_success
    body = @client.compat.applications.get('AP1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Applications/AP1", 'compatibility.get_application')
  end

  def test_get_application_error
    assert_error('compatibility.get_application', 404, 'GET',
                 "#{account_base}/Applications/missing") { @client.compat.applications.get('missing') }
  end

  def test_update_application_success
    body = @client.compat.applications.update('AP1', FriendlyName: 'renamed')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Applications/AP1",
                       'compatibility.update_application')

    assert_equal 'renamed', j.body['FriendlyName']
  end

  def test_update_application_error
    assert_error('compatibility.update_application', 404, 'POST',
                 "#{account_base}/Applications/missing") do
      @client.compat.applications.update('missing', FriendlyName: 'x')
    end
  end

  def test_delete_application_success
    @client.compat.applications.delete('AP1')

    assert_journal('DELETE', "#{account_base}/Applications/AP1", 'compatibility.delete_application')
  end

  def test_delete_application_error
    assert_error('compatibility.delete_application', 404, 'DELETE',
                 "#{account_base}/Applications/missing") do
      @client.compat.applications.delete('missing')
    end
  end

  # ===================================================================
  # LaML bins (cXML scripts)
  # ===================================================================

  def test_list_cxml_scripts_success
    body = @client.compat.laml_bins.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/LamlBins", 'compatibility.list_cxml_scripts')
  end

  def test_list_cxml_scripts_error
    assert_error('compatibility.list_cxml_scripts', 500, 'GET',
                 "#{account_base}/LamlBins") { @client.compat.laml_bins.list }
  end

  def test_create_cxml_script_success
    body = @client.compat.laml_bins.create(Name: 'bin-a', Contents: '<Response/>')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/LamlBins", 'compatibility.create_cxml_script')

    assert_equal 'bin-a', j.body['Name']
  end

  def test_create_cxml_script_error
    assert_error('compatibility.create_cxml_script', 422, 'POST', "#{account_base}/LamlBins") do
      @client.compat.laml_bins.create(Name: 'x')
    end
  end

  def test_retrieve_cxml_script_success
    body = @client.compat.laml_bins.get('LB1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/LamlBins/LB1", 'compatibility.retrieve_cxml_script')
  end

  def test_retrieve_cxml_script_error
    assert_error('compatibility.retrieve_cxml_script', 404, 'GET',
                 "#{account_base}/LamlBins/missing") { @client.compat.laml_bins.get('missing') }
  end

  def test_update_cxml_script_success
    body = @client.compat.laml_bins.update('LB1', Name: 'renamed')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/LamlBins/LB1", 'compatibility.update_cxml_script')

    assert_equal 'renamed', j.body['Name']
  end

  def test_update_cxml_script_error
    assert_error('compatibility.update_cxml_script', 404, 'POST', "#{account_base}/LamlBins/missing") do
      @client.compat.laml_bins.update('missing', Name: 'x')
    end
  end

  def test_delete_cxml_script_success
    @client.compat.laml_bins.delete('LB1')

    assert_journal('DELETE', "#{account_base}/LamlBins/LB1", 'compatibility.delete_cxml_script')
  end

  def test_delete_cxml_script_error
    assert_error('compatibility.delete_cxml_script', 404, 'DELETE',
                 "#{account_base}/LamlBins/missing") { @client.compat.laml_bins.delete('missing') }
  end

  # ===================================================================
  # Queues (+ members)
  # ===================================================================

  def test_list_queues_success
    body = @client.compat.queues.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Queues", 'compatibility.list_queues')
  end

  def test_list_queues_error
    assert_error('compatibility.list_queues', 500, 'GET',
                 "#{account_base}/Queues") { @client.compat.queues.list }
  end

  def test_create_queue_success
    body = @client.compat.queues.create(FriendlyName: 'q-a')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Queues", 'compatibility.create_queue')

    assert_equal 'q-a', j.body['FriendlyName']
  end

  def test_create_queue_error
    assert_error('compatibility.create_queue', 422, 'POST', "#{account_base}/Queues") do
      @client.compat.queues.create(FriendlyName: 'x')
    end
  end

  def test_retrieve_queue_success
    body = @client.compat.queues.get('QU1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Queues/QU1", 'compatibility.retrieve_queue')
  end

  def test_retrieve_queue_error
    assert_error('compatibility.retrieve_queue', 404, 'GET',
                 "#{account_base}/Queues/missing") { @client.compat.queues.get('missing') }
  end

  def test_update_queue_success
    body = @client.compat.queues.update('QU1', FriendlyName: 'renamed')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Queues/QU1", 'compatibility.update_queue')

    assert_equal 'renamed', j.body['FriendlyName']
  end

  def test_update_queue_error
    assert_error('compatibility.update_queue', 404, 'POST', "#{account_base}/Queues/missing") do
      @client.compat.queues.update('missing', FriendlyName: 'x')
    end
  end

  def test_delete_queue_success
    @client.compat.queues.delete('QU1')

    assert_journal('DELETE', "#{account_base}/Queues/QU1", 'compatibility.delete_queue')
  end

  def test_delete_queue_error
    assert_error('compatibility.delete_queue', 404, 'DELETE',
                 "#{account_base}/Queues/missing") { @client.compat.queues.delete('missing') }
  end

  def test_list_all_queue_members_success
    body = @client.compat.queues.list_members('QU1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Queues/QU1/Members",
                   'compatibility.list_all_queue_members')
  end

  def test_list_all_queue_members_error
    assert_error('compatibility.list_all_queue_members', 404, 'GET',
                 "#{account_base}/Queues/missing/Members") do
      @client.compat.queues.list_members('missing')
    end
  end

  def test_retrieve_queue_member_success
    body = @client.compat.queues.get_member('QU1', 'CA1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Queues/QU1/Members/CA1",
                   'compatibility.retrieve_queue_member')
  end

  def test_retrieve_queue_member_error
    assert_error('compatibility.retrieve_queue_member', 404, 'GET',
                 "#{account_base}/Queues/QU1/Members/missing") do
      @client.compat.queues.get_member('QU1', 'missing')
    end
  end

  def test_update_queue_member_success
    body = @client.compat.queues.dequeue_member('QU1', 'CA1', Url: 'https://x/y')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/Queues/QU1/Members/CA1",
                       'compatibility.update_queue_member')

    assert_equal 'https://x/y', j.body['Url']
  end

  def test_update_queue_member_error
    assert_error('compatibility.update_queue_member', 404, 'POST',
                 "#{account_base}/Queues/QU1/Members/missing") do
      @client.compat.queues.dequeue_member('QU1', 'missing', Url: 'https://x/y')
    end
  end

  # ===================================================================
  # Recordings
  # ===================================================================

  def test_list_recordings_success
    body = @client.compat.recordings.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Recordings", 'compatibility.list_recordings')
  end

  def test_list_recordings_error
    assert_error('compatibility.list_recordings', 500, 'GET',
                 "#{account_base}/Recordings") { @client.compat.recordings.list }
  end

  def test_retrieve_recording_success
    body = @client.compat.recordings.get('RE1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Recordings/RE1", 'compatibility.retrieve_recording')
  end

  def test_retrieve_recording_error
    assert_error('compatibility.retrieve_recording', 404, 'GET',
                 "#{account_base}/Recordings/missing") { @client.compat.recordings.get('missing') }
  end

  def test_delete_recording_success
    @client.compat.recordings.delete('RE1')

    assert_journal('DELETE', "#{account_base}/Recordings/RE1", 'compatibility.delete_recording')
  end

  def test_delete_recording_error
    assert_error('compatibility.delete_recording', 404, 'DELETE',
                 "#{account_base}/Recordings/missing") { @client.compat.recordings.delete('missing') }
  end

  # ===================================================================
  # Transcriptions
  # ===================================================================

  def test_list_transcriptions_success
    body = @client.compat.transcriptions.list

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Transcriptions", 'compatibility.list_transcriptions')
  end

  def test_list_transcriptions_error
    assert_error('compatibility.list_transcriptions', 500, 'GET',
                 "#{account_base}/Transcriptions") { @client.compat.transcriptions.list }
  end

  def test_retrieve_transcription_success
    body = @client.compat.transcriptions.get('TR1')

    assert_kind_of Hash, body
    assert_journal('GET', "#{account_base}/Transcriptions/TR1",
                   'compatibility.retrieve_transcription')
  end

  def test_retrieve_transcription_error
    assert_error('compatibility.retrieve_transcription', 404, 'GET',
                 "#{account_base}/Transcriptions/missing") do
      @client.compat.transcriptions.get('missing')
    end
  end

  def test_delete_transcription_success
    @client.compat.transcriptions.delete('TR1')

    assert_journal('DELETE', "#{account_base}/Transcriptions/TR1",
                   'compatibility.delete_transcription')
  end

  def test_delete_transcription_error
    assert_error('compatibility.delete_transcription', 404, 'DELETE',
                 "#{account_base}/Transcriptions/missing") do
      @client.compat.transcriptions.delete('missing')
    end
  end

  # ===================================================================
  # Tokens
  # ===================================================================

  def test_create_token_success
    body = @client.compat.tokens.create(name: 'tok-a')

    assert_kind_of Hash, body
    j = assert_journal('POST', "#{account_base}/tokens", 'compatibility.create_token')

    assert_equal 'tok-a', j.body['name']
  end

  def test_create_token_error
    assert_error('compatibility.create_token', 422, 'POST', "#{account_base}/tokens") do
      @client.compat.tokens.create(name: 'x')
    end
  end

  def test_update_token_success
    body = @client.compat.tokens.update('tok1', name: 'renamed')

    assert_kind_of Hash, body
    j = assert_journal('PATCH', "#{account_base}/tokens/tok1", 'compatibility.update_token')

    assert_equal 'renamed', j.body['name']
  end

  def test_update_token_error
    assert_error('compatibility.update_token', 404, 'PATCH', "#{account_base}/tokens/missing") do
      @client.compat.tokens.update('missing', name: 'x')
    end
  end

  def test_delete_token_success
    @client.compat.tokens.delete('tok1')

    assert_journal('DELETE', "#{account_base}/tokens/tok1", 'compatibility.delete_token')
  end

  def test_delete_token_error
    assert_error('compatibility.delete_token', 404, 'DELETE', "#{account_base}/tokens/missing") do
      @client.compat.tokens.delete('missing')
    end
  end
end
# rubocop:enable Metrics/ClassLength
