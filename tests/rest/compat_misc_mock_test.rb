# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_misc.py.
#
# Covers single-method gaps:
#
#   - CompatApplications.update
#   - CompatLamlBins.update

require 'minitest/autorun'
require_relative 'mock_test'

class CompatMiscMockTest < Minitest::Test
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

  # ---- Applications.update --------------------------------------------

  def test_applications_update_returns_application_resource
    result = @client.compat.applications.update('AP_U', FriendlyName: 'updated')

    assert_kind_of Hash, result
    # Application resources carry friendly_name + sid + voice_url.
    assert(result.key?('friendly_name') || result.key?('sid'))
  end

  def test_applications_update_journal_records_post_with_friendly_name
    @client.compat.applications.update(
      'AP_UU', FriendlyName: 'renamed', VoiceUrl: 'https://a.b/v'
    )
    j = @mock.last
    body = j.body

    assert_equal 'POST', j.method
    assert_equal "#{account_base}/Applications/AP_UU", j.path
    assert_kind_of Hash, body
    assert_equal 'renamed', body['FriendlyName']
    assert_equal 'https://a.b/v', body['VoiceUrl']
  end

  # ---- LamlBins.update ------------------------------------------------

  def test_laml_bins_update_returns_laml_bin_resource
    result = @client.compat.laml_bins.update('LB_U', FriendlyName: 'updated')

    assert_kind_of Hash, result
    # LAML bin resources carry friendly_name + sid + contents.
    assert(result.key?('friendly_name') || result.key?('sid') || result.key?('contents'))
  end

  def test_laml_bins_update_journal_records_post_with_friendly_name
    @client.compat.laml_bins.update(
      'LB_UU', FriendlyName: 'renamed', Contents: '<Response/>'
    )
    j = @mock.last
    body = j.body

    assert_equal 'POST', j.method
    assert_equal "#{account_base}/LamlBins/LB_UU", j.path
    assert_kind_of Hash, body
    assert_equal 'renamed', body['FriendlyName']
    assert_equal '<Response/>', body['Contents']
  end
end
