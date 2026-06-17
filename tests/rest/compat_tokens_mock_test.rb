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
  ACCOUNT_BASE = '/api/laml/2010-04-01/Accounts/test_proj'
  TOKENS_BASE  = "#{ACCOUNT_BASE}/tokens"

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
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
    j = MockTest.journal.last

    assert_equal 'POST', j.method
    assert_equal TOKENS_BASE, j.path
    assert_kind_of Hash, j.body
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
    j = MockTest.journal.last
    # CompatTokens.update uses PATCH (BaseResource.update -> http.patch).
    assert_equal 'PATCH', j.method
    assert_equal "#{TOKENS_BASE}/TK_UU", j.path
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
    j = MockTest.journal.last

    assert_equal 'DELETE', j.method
    assert_equal "#{TOKENS_BASE}/TK_DEL", j.path
  end
end
