# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/native_vector_search'

class VectorSearchSkillDetailedTest < Minitest::Test
  def test_setup_requires_remote_url
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({})

    refute skill.setup

    skill_with_url = factory.call({ 'remote_url' => 'https://example.com/search' })

    assert skill_with_url.setup
  end

  def test_register_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search' })
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_equal 'search_knowledge', tools[0][:name]
  end

  def test_custom_tool_name
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search', 'tool_name' => 'find_docs' })
    skill.setup
    tools = skill.register_tools

    assert_equal 'find_docs', tools[0][:name]
  end

  def test_get_hints
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search' })
    skill.setup
    hints = skill.get_hints

    assert_includes hints, 'search'
    assert_includes hints, 'documentation'
  end

  def test_custom_hints
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search', 'hints' => ['custom'] })
    skill.setup
    hints = skill.get_hints

    assert_includes hints, 'custom'
  end

  def test_empty_query_returns_message
    factory = SignalWire::Skills::SkillRegistry.get_factory('native_vector_search')
    skill = factory.call({ 'remote_url' => 'https://example.com/search' })
    skill.setup
    tools = skill.register_tools
    handler = tools[0][:handler]
    result = handler.call({ 'query' => '' }, {})

    assert_includes result.response, 'provide a search query'
  end
end
