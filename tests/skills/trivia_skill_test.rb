# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/api_ninjas_trivia'

class TriviaSkillDetailedTest < Minitest::Test
  def test_setup_requires_api_key
    saved = ENV.delete('API_NINJAS_KEY')
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('api_ninjas_trivia')
      skill = factory.call({})

      refute skill.setup

      skill_with_key = factory.call({ 'api_key' => 'test_key' })

      assert skill_with_key.setup
    ensure
      ENV['API_NINJAS_KEY'] = saved if saved
    end
  end

  def test_register_tools_returns_datamap
    factory = SignalWire::Skills::SkillRegistry.get_factory('api_ninjas_trivia')
    skill = factory.call({ 'api_key' => 'test_key' })
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert tools[0].key?(:datamap)
  end

  def test_valid_categories
    cats = SignalWire::Skills::Builtin::ApiNinjasTriviaSkill::VALID_CATEGORIES

    assert cats.key?('general')
    assert cats.key?('music')
    assert_equal 14, cats.size
  end

  def test_supports_multiple_instances
    factory = SignalWire::Skills::SkillRegistry.get_factory('api_ninjas_trivia')
    skill = factory.call({})

    assert_predicate skill, :supports_multiple_instances?
  end
end
