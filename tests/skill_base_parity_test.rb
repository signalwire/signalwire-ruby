# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

# Parity tests for the skill-data share helpers, env/package validation,
# and the registry discovery / source-listing surface. Mirrors Python's
# signalwire.core.skill_base.SkillBase (get_skill_data / update_skill_data
# / validate_env_vars / validate_packages) and
# signalwire.skills.registry.SkillRegistry (discover_skills /
# list_all_skill_sources), plus top-level signalwire.list_skills.

require 'minitest/autorun'

require_relative '../lib/signalwire/swaig/function_result'
require_relative '../lib/signalwire/skills/skill_base'
require_relative '../lib/signalwire/skills/skill_registry'
require_relative '../lib/signalwire'

# Concrete skill used to exercise SkillBase helpers. Declares one
# required env var, one required package, and supports the multi-instance
# prefix/tool_name namespacing so we can prove collision-free state.
class ParitySkill < SignalWire::Skills::SkillBase
  def name = 'parity_skill'
  def description = 'Parity test skill'
  def supports_multiple_instances? = true

  def required_env_vars = ['PARITY_REQUIRED_VAR']
  # 'json' is a stdlib gem, always loadable.
  def required_packages = ['json']

  # Multi-instance key, mirroring the built-in skills' shape.
  def instance_key
    tool_name = get_param('tool_name', default: name)
    "#{name}_#{tool_name}"
  end
end

class SkillBaseHelpersTestBase < Minitest::Test
  def make_skill(params = {})
    ParitySkill.new(nil, params)
  end
end

class SkillBaseDataHelpersTest < SkillBaseHelpersTestBase
  # --- get_skill_data -------------------------------------------------

  def test_get_skill_data_returns_stored_namespaced_hash
    skill = make_skill
    namespace = "skill:#{skill.instance_key}"
    stored = { 'count' => 3, 'last' => 'hello' }
    raw_data = { 'global_data' => { namespace => stored, 'other' => { 'x' => 1 } } }

    assert_equal stored, skill.get_skill_data(raw_data)
  end

  def test_get_skill_data_returns_empty_hash_when_namespace_absent
    skill = make_skill
    raw_data = { 'global_data' => { 'skill:someone_else' => { 'k' => 'v' } } }

    assert_equal({}, skill.get_skill_data(raw_data))
  end

  def test_get_skill_data_returns_empty_hash_when_no_global_data
    skill = make_skill

    assert_equal({}, skill.get_skill_data({}))
    assert_equal({}, skill.get_skill_data(nil))
  end

  def test_get_skill_data_honors_prefix_param_namespace
    skill = make_skill('prefix' => 'mine')
    stored = { 'a' => 1 }
    raw_data = { 'global_data' => { 'skill:mine' => stored } }

    assert_equal stored, skill.get_skill_data(raw_data)
  end

  def test_get_skill_data_isolates_instances_by_namespace
    a = make_skill('tool_name' => 'alpha')
    b = make_skill('tool_name' => 'beta')
    raw_data = {
      'global_data' => {
        "skill:#{a.instance_key}" => { 'who' => 'alpha' },
        "skill:#{b.instance_key}" => { 'who' => 'beta' }
      }
    }

    assert_equal({ 'who' => 'alpha' }, a.get_skill_data(raw_data))
    assert_equal({ 'who' => 'beta' }, b.get_skill_data(raw_data))
  end

  # --- update_skill_data ---------------------------------------------

  def test_update_skill_data_writes_namespaced_set_global_data_action
    skill = make_skill
    namespace = "skill:#{skill.instance_key}"
    result = SignalWire::Swaig::FunctionResult.new('ok')

    returned = skill.update_skill_data(result, { 'count' => 5 })

    # Returns the result for chaining (Python returns result).
    assert_same result, returned

    action = result.to_h['action'].find { |a| a.key?('set_global_data') }

    refute_nil action, "expected a set_global_data action: #{result.to_h.inspect}"
    assert_equal({ namespace => { 'count' => 5 } }, action['set_global_data'])
  end

  def test_update_skill_data_roundtrips_via_get_skill_data
    # Writing with update_skill_data then reading the resulting global_data
    # bucket back through get_skill_data yields the same payload.
    skill = make_skill('tool_name' => 'rt')
    result = SignalWire::Swaig::FunctionResult.new('ok')
    payload = { 'visited' => %w[a b c] }

    skill.update_skill_data(result, payload)
    action = result.to_h['action'].find { |a| a.key?('set_global_data') }
    raw_data = { 'global_data' => action['set_global_data'] }

    assert_equal payload, skill.get_skill_data(raw_data)
  end
end

# --- validate_env_vars + validate_packages ---------------------------
class SkillBaseValidationTest < SkillBaseHelpersTestBase
  def test_validate_env_vars_false_when_required_var_unset_then_true_when_set
    saved = ENV.delete('PARITY_REQUIRED_VAR')
    begin
      skill = make_skill

      refute skill.validate_env_vars, 'should be false when required var unset'

      ENV['PARITY_REQUIRED_VAR'] = 'present'

      assert skill.validate_env_vars, 'should be true once required var set'
    ensure
      ENV['PARITY_REQUIRED_VAR'] = saved if saved
      ENV.delete('PARITY_REQUIRED_VAR') unless saved
    end
  end

  def test_validate_env_vars_true_when_no_requirements
    plain = Class.new(SignalWire::Skills::SkillBase) do
      define_method(:name)        { 'no_env_skill' }
      define_method(:description) { 'x' }
    end.new(nil, {})

    assert plain.validate_env_vars
  end

  def test_validate_env_vars_treats_empty_string_as_missing
    saved = ENV.fetch('PARITY_REQUIRED_VAR', nil)
    begin
      ENV['PARITY_REQUIRED_VAR'] = ''

      refute make_skill.validate_env_vars, 'empty string should count as missing'
    ensure
      saved ? ENV['PARITY_REQUIRED_VAR'] = saved : ENV.delete('PARITY_REQUIRED_VAR')
    end
  end

  # --- validate_packages ---------------------------------------------

  def test_validate_packages_true_for_present_gem
    # ParitySkill requires 'json', a stdlib gem that always loads.
    assert make_skill.validate_packages
  end

  def test_validate_packages_false_for_bogus_required_package
    bogus = Class.new(SignalWire::Skills::SkillBase) do
      define_method(:name)              { 'bogus_pkg_skill' }
      define_method(:description)       { 'x' }
      define_method(:required_packages) { ['this_gem_does_not_exist_xyz_42'] }
    end.new(nil, {})

    refute bogus.validate_packages, 'should be false when a required gem is unloadable'
  end

  def test_validate_packages_true_when_no_requirements
    plain = Class.new(SignalWire::Skills::SkillBase) do
      define_method(:name)        { 'no_pkg_skill' }
      define_method(:description) { 'x' }
    end.new(nil, {})

    assert plain.validate_packages
  end
end

class SkillRegistryDiscoveryTest < Minitest::Test
  def setup
    SignalWire::Skills::SkillRegistry.register_builtins!
  end

  # --- discover_skills ------------------------------------------------

  def test_discover_skills_returns_registered_builtin_names
    names = SignalWire::Skills::SkillRegistry.discover_skills

    assert_kind_of Array, names
    assert_includes names, 'datetime'
    assert_includes names, 'math'
  end

  def test_discover_skills_is_idempotent
    first  = SignalWire::Skills::SkillRegistry.discover_skills.sort
    second = SignalWire::Skills::SkillRegistry.discover_skills.sort

    assert_equal first, second
  end

  def test_discover_skills_instance_form_matches_class_form
    registry = SignalWire::Skills::SkillRegistry.new

    assert_includes registry.discover_skills, 'datetime'
  end

  # --- list_all_skill_sources ----------------------------------------

  def test_list_all_skill_sources_has_four_source_buckets
    sources = SignalWire::Skills::SkillRegistry.list_all_skill_sources

    assert_kind_of Hash, sources
    %w[built-in external_paths entry_points registered].each do |key|
      assert sources.key?(key), "missing source bucket: #{key}"
      assert_kind_of Array, sources[key]
    end
  end

  def test_list_all_skill_sources_built_in_includes_shipped_skills
    sources = SignalWire::Skills::SkillRegistry.list_all_skill_sources

    assert_includes sources['built-in'], 'datetime'
    assert_includes sources['built-in'], 'web_search'
  end

  def test_list_all_skill_sources_registered_excludes_built_ins
    # A freshly registered non-built-in skill shows up under 'registered',
    # and no built-in name leaks into that bucket.
    with_extra_registered_skill('parity_extra_skill') do
      sources = SignalWire::Skills::SkillRegistry.list_all_skill_sources

      assert_includes sources['registered'], 'parity_extra_skill'
      assert_empty(sources['registered'] & sources['built-in'],
                   'built-in skills must not appear under registered')
    end
  end

  def with_extra_registered_skill(name)
    SignalWire::Skills::SkillRegistry.register_skill(name, ->(_params = {}) { ParitySkill.new(nil, {}) })
    yield
  ensure
    SignalWire::Skills::SkillRegistry.instance_variable_get(:@factories).delete(name)
  end
end

class TopLevelListSkillsTest < Minitest::Test
  def setup
    SignalWire::Skills::SkillRegistry.register_builtins!
  end

  # --- SignalWire.list_skills ----------------------------------------

  def test_top_level_list_skills_returns_array_of_named_hashes
    skills = SignalWire.list_skills

    assert_kind_of Array, skills
    refute_empty skills
    skills.each do |entry|
      assert_kind_of Hash, entry
      assert entry.key?('name'), "expected 'name' key in #{entry.inspect}"
    end
  end

  def test_top_level_list_skills_includes_known_builtins
    names = SignalWire.list_skills.map { |e| e['name'] }

    assert_includes names, 'datetime'
    assert_includes names, 'math'
  end
end
