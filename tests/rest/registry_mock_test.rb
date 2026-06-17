# frozen_string_literal: true

# Mock-backed unit tests translated from
# signalwire-python/tests/unit/rest/test_registry_mock.py.
#
# The 10DLC Campaign Registry namespace exposes four sub-resources:
# brands, campaigns, orders, and numbers. The legacy tests only touched
# brands.create and campaigns.list_orders; this module closes the rest.

require 'minitest/autorun'
require_relative 'mock_test'

class RegistryMockTest < Minitest::Test
  REG_BASE = '/api/relay/rest/registry/beta'

  def setup
    @client = MockTest.client
    MockTest.reset
  end

  def teardown
    MockTest.reset
  end

  # ---- Brands ---------------------------------------------------------

  def test_brands_list_returns_dict
    body = @client.registry.brands.list

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{REG_BASE}/brands", last.path
    refute_nil last.matched_route, 'spec gap: brand list'
  end

  def test_brands_get_uses_id_in_path
    body = @client.registry.brands.get('brand-77')

    assert_kind_of Hash, body
    # Single-brand endpoint synthesises one resource object.

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{REG_BASE}/brands/brand-77", last.path
  end

  def test_brands_list_campaigns_uses_brand_subpath
    body = @client.registry.brands.list_campaigns('brand-1')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{REG_BASE}/brands/brand-1/campaigns", last.path
    refute_nil last.matched_route
  end

  def test_brands_create_campaign_posts_to_brand_subpath
    body = @client.registry.brands.create_campaign(
      'brand-2', usecase: 'LOW_VOLUME', description: 'MFA'
    )

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'POST', last.method
    assert_equal "#{REG_BASE}/brands/brand-2/campaigns", last.path
    assert_kind_of Hash, last.body
    assert_equal 'LOW_VOLUME', last.body['usecase']
    assert_equal 'MFA', last.body['description']
  end

  # ---- Campaigns ------------------------------------------------------

  def test_campaigns_get_uses_id_in_path
    body = @client.registry.campaigns.get('camp-1')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{REG_BASE}/campaigns/camp-1", last.path
  end

  def test_campaigns_update_uses_put
    # RegistryCampaigns.update calls @http.put(...) — distinct from the
    # generic CrudResource which uses PATCH.
    body = @client.registry.campaigns.update('camp-2', description: 'Updated')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'PUT', last.method
    assert_equal "#{REG_BASE}/campaigns/camp-2", last.path
    assert_kind_of Hash, last.body
    assert_equal 'Updated', last.body['description']
  end

  def test_campaigns_list_numbers_uses_numbers_subpath
    body = @client.registry.campaigns.list_numbers('camp-3')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{REG_BASE}/campaigns/camp-3/numbers", last.path
    refute_nil last.matched_route
  end

  def test_campaigns_create_order_posts_to_orders_subpath
    body = @client.registry.campaigns.create_order(
      'camp-4', numbers: %w[pn-1 pn-2]
    )

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'POST', last.method
    assert_equal "#{REG_BASE}/campaigns/camp-4/orders", last.path
    assert_kind_of Hash, last.body
    assert_equal %w[pn-1 pn-2], last.body['numbers']
  end

  # ---- Orders ---------------------------------------------------------

  def test_orders_get_uses_id_in_path
    body = @client.registry.orders.get('order-1')

    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'GET', last.method
    assert_equal "#{REG_BASE}/orders/order-1", last.path
    refute_nil last.matched_route, 'spec gap: order retrieve'
  end

  # ---- Numbers --------------------------------------------------------

  def test_numbers_delete_uses_id_in_path
    body = @client.registry.numbers.delete('num-1')
    # SDK turns 204/empty into {} so we still get a dict back.
    assert_kind_of Hash, body

    last = MockTest.journal.last

    assert_equal 'DELETE', last.method
    assert_equal "#{REG_BASE}/numbers/num-1", last.path
    refute_nil last.matched_route
  end
end
