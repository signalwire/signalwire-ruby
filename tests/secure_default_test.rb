# frozen_string_literal: true

require 'minitest/autorun'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# A1 secure-default contract (A+ campaign): AgentBase#define_tool defaults
# secure=true fleet-wide, and a SECURE tool rendered with an active call_id
# carries a per-tool __token on its SWAIG web_hook_url (the wire manifestation of
# secure). A secure=false tool carries NO __token. Mirrors the cross-port
# SECURE-DEFAULT gate (porting-sdk secure_default_corpus / the python oracle).
class SecureDefaultTest < Minitest::Test
  CALL_ID = 'call-secure-default-fixture'

  def setup
    @agent = SignalWire::AgentBase.new(name: 'secure-default-fixture', route: '/sd')
  end

  # The SDK-recorded flag: a default define_tool is secure; secure:false is not.
  def test_define_tool_defaults_secure_true
    @agent.define_tool(name: 'a', description: 'd', parameters: {}) { |_a, _r| nil }
    @agent.define_tool(name: 'b', description: 'd', parameters: {}, secure: false) { |_a, _r| nil }

    tools = @agent.instance_variable_get(:@tools)

    assert tools['a'][:secure], 'a default define_tool must be secure by default (A1)'
    refute tools['b'][:secure], 'secure:false must stay insecure'
  end

  # The wire manifestation: with a call_id, the secure tool's webhook carries a
  # __token; the insecure tool's does not.
  def test_secure_tool_webhook_carries_token_with_call_id
    @agent.define_tool(name: 'sd_default_secure', description: 'd', parameters: {}) { |_a, _r| nil }
    @agent.define_tool(name: 'sd_explicit_insecure', description: 'd',
                       parameters: {}, secure: false) { |_a, _r| nil }

    fns = swaig_functions(@agent.send(:_render_swml_internal, call_id: CALL_ID))
    by_name = fns.to_h { |f| [f['function'], f] }

    assert_includes(by_name['sd_default_secure']['web_hook_url'].to_s, '__token=',
                    'a secure tool rendered with a call_id must carry a per-tool __token')
    refute_includes((by_name['sd_explicit_insecure']['web_hook_url'] || '').to_s, '__token=',
                    'an insecure tool must NOT carry a __token')
  end

  # Without a call_id, no token is minted (the render is call-agnostic).
  def test_no_token_without_call_id
    @agent.define_tool(name: 'sd_default_secure', description: 'd', parameters: {}) { |_a, _r| nil }
    fns = swaig_functions(@agent.send(:_render_swml_internal))
    entry = fns.find { |f| f['function'] == 'sd_default_secure' } || {}

    refute_includes((entry['web_hook_url'] || '').to_s, '__token=',
                    'no call_id → no per-tool token')
  end

  private

  def swaig_functions(doc)
    ai = doc['sections']['main'].find { |s| s.is_a?(Hash) && s.key?('ai') }
    ai&.dig('ai', 'SWAIG', 'functions') || []
  end
end
