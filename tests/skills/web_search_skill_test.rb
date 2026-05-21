# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/web_search'

class WebSearchSkillDetailedTest < Minitest::Test
  def test_setup_requires_api_key_and_engine_id
    saved_key = ENV.delete('GOOGLE_SEARCH_API_KEY')
    saved_cx  = ENV.delete('GOOGLE_SEARCH_ENGINE_ID')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
      skill = factory.call({})
      refute skill.setup

      skill_partial = factory.call({ 'api_key' => 'key' })
      refute skill_partial.setup

      skill_full = factory.call({ 'api_key' => 'key', 'search_engine_id' => 'cx' })
      assert skill_full.setup
    ensure
      ENV['GOOGLE_SEARCH_API_KEY'] = saved_key if saved_key
      ENV['GOOGLE_SEARCH_ENGINE_ID'] = saved_cx if saved_cx
    end
  end

  def test_register_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'key', 'search_engine_id' => 'cx' })
    skill.setup
    tools = skill.register_tools
    assert_equal 1, tools.size
    assert_equal 'web_search', tools[0][:name]
  end

  def test_supports_multiple_instances
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx' })
    assert skill.supports_multiple_instances?
  end

  def test_instance_key_includes_tool_name
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx', 'tool_name' => 'custom_search' })
    skill.setup
    assert_includes skill.instance_key, 'custom_search'
  end

  def test_version
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({})
    assert_equal '2.0.0', skill.version
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx' })
    skill.setup
    data = skill.get_global_data
    assert_equal true, data['web_search_enabled']
  end
end

# Ports Python 8aad242: response_prefix / response_postfix wrap a
# successful (non-empty) search result. Empty search results, empty
# query, and error paths do NOT receive the prefix/postfix.
class WebSearchSkillResponsePrefixPostfixTest < Minitest::Test
  def make_skill(params = {})
    factory = SignalWire::Skills::SkillRegistry.get_factory('web_search')
    skill = factory.call({ 'api_key' => 'k', 'search_engine_id' => 'cx' }.merge(params))
    skill.setup
    skill
  end

  # Stub google_search to return a fixed result list; this avoids needing
  # the mock HTTP server in a unit test of the wrapping logic.
  def stub_search(skill, results)
    skill.singleton_class.send(:define_method, :google_search) do |_q, _n|
      results
    end
  end

  def test_response_prefix_prepended_on_success
    skill = make_skill('response_prefix' => 'NOTE-FROM-WEB-SEARCH')
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s
    assert_match(/NOTE-FROM-WEB-SEARCH/, body)
    assert_match(/Web search results for 'cats'/, body)
  end

  def test_response_postfix_appended_on_success
    skill = make_skill('response_postfix' => 'CITE-THE-URL-PLEASE')
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s
    assert_match(/CITE-THE-URL-PLEASE/, body)
  end

  def test_response_prefix_and_postfix_both_applied
    skill = make_skill('response_prefix' => 'PRE-MARK', 'response_postfix' => 'POST-MARK')
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s
    assert_match(/PRE-MARK/, body)
    assert_match(/POST-MARK/, body)
  end

  def test_response_prefix_not_applied_when_no_results
    skill = make_skill('response_prefix' => 'SHOULD-NOT-APPEAR',
                       'no_results_message' => 'nothing found')
    stub_search(skill, [])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s
    refute_match(/SHOULD-NOT-APPEAR/, body)
    assert_match(/nothing found/, body)
  end

  def test_empty_prefix_and_postfix_leave_response_unchanged
    skill = make_skill
    stub_search(skill, [{ 'title' => 'T', 'url' => 'http://u', 'snippet' => 'S' }])
    result = skill.send(:handle_search, { 'query' => 'cats' }, nil)
    body = result.response.to_s
    # No spurious leading/trailing markers; only the canonical
    # "Web search results for 'cats':" header is present.
    assert body.start_with?("Web search results for 'cats':"),
           "expected body to start with the canonical header, got: #{body[0, 80].inspect}"
  end

  def test_parameter_schema_advertises_prefix_postfix
    skill = make_skill
    schema = skill.get_parameter_schema
    assert schema.key?('response_prefix')
    assert schema.key?('response_postfix')
  end
end
