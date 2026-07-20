# frozen_string_literal: true

# Mock-backed test: the REST client sends a correct, versioned User-Agent on the
# wire. Mirrors the Python reference fix (rest/_base.py `_user_agent`): the
# product token is the stable `signalwire-ruby` and the version segment is the
# real SDK version, never a hardcoded `/1.0` (SDK_BUG_LEDGER P1: the old
# `signalwire-agents-ruby-rest/1.0` was both the wrong product token and a stale
# version). Asserted against the real mock's journal, not a transport fake.

require 'minitest/autorun'
require_relative 'mock_test'
require_relative '../../lib/signalwire/version'

class RestUserAgentMockTest < Minitest::Test
  def setup
    h = MockTest.client
    @client = h[:client]
    @mock   = h[:mock]
  end

  def test_rest_user_agent_is_versioned_product_token
    @client.phone_numbers.search(areacode: '512')

    ua = @mock.last.headers['user-agent'] || @mock.last.headers['User-Agent']

    refute_nil ua, 'REST request carried no User-Agent header'
    assert_equal "signalwire-ruby/#{SignalWire::VERSION}", ua
    refute_match(/agents-ruby-rest/, ua, 'stale wrong product token still on the wire')
    refute_match(%r{/1\.0\z}, ua, 'stale hardcoded /1.0 version still on the wire')
  end
end
