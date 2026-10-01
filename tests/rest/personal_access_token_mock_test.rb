# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'mock_test'

# The Space Administration API (client.space) authenticates with a user's Personal
# Access Token: HTTP Basic with an EMPTY username (prime-rails
# API::Space::BaseController -> Authenticators::PersonalAccessToken). Either
# credential, or both, may be given; a resource whose credential is missing
# refuses before anything is sent. Mirrors the reference RestClient
# (signalwire/rest/client.py).
class PersonalAccessTokenMockTest < Minitest::Test
  def test_space_request_carries_the_pat_as_basic_with_empty_username
    h = MockTest.pat_client
    h[:client].space.members.list

    last = h[:mock].last

    assert_equal 'GET', last.method
    assert_equal 'space.list_members', last.matched_route
  end

  def test_project_resources_on_a_both_credential_client_keep_the_project_token
    h = MockTest.pat_client
    h[:client].phone_numbers.list

    # A harness view scoped to the PROJECT credential's header sees the request.
    assert_equal '/api/relay/rest/phone_numbers', project_view(h[:project]).last.path
    assert_empty h[:mock].journal, 'the PAT-scoped view must not see a project-token request'
  end

  def test_pat_only_client_refuses_a_project_resource_before_sending
    client = SignalWire::REST::RestClient.new(personal_access_token: 'pat_x', base_url: MockTest.harness.url)

    err = assert_raises(ArgumentError) { client.phone_numbers.list }
    assert_match(/project and token are required/, err.message)
  end

  def test_project_only_client_refuses_client_space_before_sending
    with_env('SIGNALWIRE_PERSONAL_ACCESS_TOKEN' => nil) do
      client = SignalWire::REST::RestClient.new(project: 'p', token: 't', base_url: MockTest.harness.url)

      err = assert_raises(ArgumentError) { client.space.members.list }
      assert_match(/personal_access_token is required/, err.message)
    end
  end

  def test_neither_credential_raises_at_construction
    with_env('SIGNALWIRE_PROJECT_ID' => nil, 'SIGNALWIRE_API_TOKEN' => nil,
             'SIGNALWIRE_PERSONAL_ACCESS_TOKEN' => nil) do
      assert_raises(ArgumentError) { SignalWire::REST::RestClient.new(host: 'example.signalwire.com') }
    end
  end

  def test_pat_falls_back_to_its_environment_variable
    with_env('SIGNALWIRE_PROJECT_ID' => nil, 'SIGNALWIRE_API_TOKEN' => nil,
             'SIGNALWIRE_PERSONAL_ACCESS_TOKEN' => 'pat_env') do
      client = SignalWire::REST::RestClient.new(host: 'example.signalwire.com')

      assert_kind_of SignalWire::REST::Namespaces::Generated::SpaceNamespace, client.space
    end
  end

  private

  def project_view(project)
    view = MockTest::Harness.new(MockTest.harness.url, MockTest.harness.port)
    view.auth_header = "Basic #{Base64.strict_encode64("#{project}:#{MockTest::REST_TOKEN}")}"
    view
  end

  def with_env(vars)
    saved = vars.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    saved.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end
end
