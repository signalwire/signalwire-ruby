# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/wikipedia_search'

class WikipediaSkillDetailedTest < Minitest::Test
  def test_setup_always_succeeds
    factory = SignalWire::Skills::SkillRegistry.get_factory('wikipedia_search')
    skill = factory.call({})

    assert skill.setup
  end

  def test_name_and_description
    factory = SignalWire::Skills::SkillRegistry.get_factory('wikipedia_search')
    skill = factory.call({})

    assert_equal 'wikipedia_search', skill.name
    assert_includes skill.description, 'Wikipedia'
  end

  def test_register_tools
    factory = SignalWire::Skills::SkillRegistry.get_factory('wikipedia_search')
    skill = factory.call({})
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_equal 'search_wiki', tools[0][:name]
    assert tools[0][:parameters].key?('query')
  end

  def test_prompt_sections
    factory = SignalWire::Skills::SkillRegistry.get_factory('wikipedia_search')
    skill = factory.call({})
    skill.setup
    sections = skill.get_prompt_sections

    assert_equal 1, sections.size
    assert_equal 'Wikipedia Search', sections[0]['title']
  end

  def test_parameter_schema
    factory = SignalWire::Skills::SkillRegistry.get_factory('wikipedia_search')
    skill = factory.call({})
    schema = skill.get_parameter_schema

    assert schema.key?('num_results')
  end
end
