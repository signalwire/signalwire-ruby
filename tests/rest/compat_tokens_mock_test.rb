# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_compat_tokens.py.
#
# Covers CompatTokens.create / .update / .delete. Note: CompatTokens
# extends BaseResource (not CrudResource), so its update uses PATCH
# rather than POST.

require 'minitest/autorun'
require_relative 'mock_test'

class CompatTokensMockTest < Minitest::Test
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

  def tokens_base
    "#{account_base}/tokens"
  end

  # ---- create ----------------------------------------------------------

  def test_create_returns_token_resource
    result = @client.compat.tokens.create(Ttl: 3600)

    assert_kind_of Hash, result
    # Token resources carry id + token + permissions.
    assert(result.key?('token') || result.key?('id'))
  end

  def test_create_journal_records_post_with_ttl
    @client.compat.tokens.create(Ttl: 3600, Name: 'api-key')
    j = @mock.last

    assert_journal_request(j, 'POST', tokens_base)
    assert_equal 3600, j.body['Ttl']
    assert_equal 'api-key', j.body['Name']
  end

  # ---- update ---------------------------------------------------------

  def test_update_returns_token_resource
    result = @client.compat.tokens.update('TK_U', Ttl: 7200)

    assert_kind_of Hash, result
    assert(result.key?('token') || result.key?('id'))
  end

  def test_update_journal_records_patch_with_ttl
    @client.compat.tokens.update('TK_UU', Ttl: 7200)
    j = @mock.last
    # CompatTokens.update uses PATCH (BaseResource.update -> http.patch).
    assert_equal 'PATCH', j.method
    assert_equal "#{tokens_base}/TK_UU", j.path
    assert_kind_of Hash, j.body
    assert_equal 7200, j.body['Ttl']
  end

  # ---- delete ---------------------------------------------------------

  def test_delete_no_exception_on_delete
    result = @client.compat.tokens.delete('TK_D')

    assert_kind_of Hash, result
  end

  def test_delete_journal_records_delete
    @client.compat.tokens.delete('TK_DEL')
    j = @mock.last

    assert_equal 'DELETE', j.method
    assert_equal "#{tokens_base}/TK_DEL", j.path
  end

  private

  # Assert a journal entry's HTTP method, path, and that it carries a Hash body.
  def assert_journal_request(entry, method, path)
    assert_equal method, entry.method
    assert_equal path, entry.path
    assert_kind_of Hash, entry.body
  end
end
