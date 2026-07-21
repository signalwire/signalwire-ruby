# frozen_string_literal: true

require_relative '../test_helper'

class RegistryDetailedTest < Minitest::Test
  EXPECTED_SKILLS = TestHelper::BUILTIN_SKILL_NAMES

  def test_has_all_builtin_skills
    registered = SignalWire::Skills::SkillRegistry.list_skills.sort

    EXPECTED_SKILLS.each do |skill_name|
      assert_includes registered, skill_name, "Missing skill: #{skill_name}"
    end
    # mcp_gateway CLIENT skill IS ported (Python-only server half excluded).
    assert_operator registered.size, :>=, EXPECTED_SKILLS.size
  end

  def test_each_skill_can_be_instantiated
    EXPECTED_SKILLS.each do |skill_name|
      factory = SignalWire::Skills::SkillRegistry.get_factory(skill_name)

      refute_nil factory, "No factory for: #{skill_name}"
      skill = factory.call({})

      assert_kind_of SignalWire::Skills::SkillBase, skill
      assert_equal skill_name, skill.name
    end
  end

  def test_registered_check
    assert SignalWire::Skills::SkillRegistry.registered?('datetime')
    refute SignalWire::Skills::SkillRegistry.registered?('nonexistent_skill_xyz')
  end

  def test_get_factory_returns_nil_for_unknown
    assert_nil SignalWire::Skills::SkillRegistry.get_factory('nonexistent_skill_xyz')
  end
end

class ManagerDetailedTest < Minitest::Test
  def setup
    @manager = SignalWire::Skills::SkillManager.new
  end

  def test_load_and_get
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    skill = factory.call({})
    @manager.load('datetime', skill)

    assert @manager.loaded?('datetime')
    assert_equal skill, @manager.get('datetime')
    assert_equal 1, @manager.size
  end

  def test_unload
    factory = SignalWire::Skills::SkillRegistry.get_factory('math')
    skill = factory.call({})
    @manager.load('math', skill)
    removed = @manager.unload('math')

    assert_equal skill, removed
    refute @manager.loaded?('math')
  end

  def test_load_duplicate_raises
    factory = SignalWire::Skills::SkillRegistry.get_factory('datetime')
    skill = factory.call({})
    @manager.load('datetime', skill)
    assert_raises(ArgumentError) { @manager.load('datetime', skill) }
  end

  def test_loaded_keys
    %w[datetime math].each do |name|
      factory = SignalWire::Skills::SkillRegistry.get_factory(name)
      @manager.load(name, factory.call({}))
    end
    keys = @manager.loaded_keys.sort

    assert_equal %w[datetime math], keys
  end

  def test_clear
    %w[datetime math].each do |name|
      factory = SignalWire::Skills::SkillRegistry.get_factory(name)
      @manager.load(name, factory.call({}))
    end
    @manager.clear

    assert_equal 0, @manager.size
  end
end
