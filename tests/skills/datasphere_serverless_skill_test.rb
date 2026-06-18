# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/datamap/data_map'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/datasphere_serverless'

class DatasphereServerlessSkillDetailedTest < Minitest::Test
  def test_setup_requires_all_params
    saved = %w[SIGNALWIRE_PROJECT_ID SIGNALWIRE_TOKEN].to_h { |k| [k, ENV.delete(k)] }
    factory = SignalWire::Skills::SkillRegistry.get_factory('datasphere_serverless')

    refute factory.call({}).setup
    assert build_full_skill(factory).setup
  ensure
    saved.each { |k, v| ENV[k] = v if v }
  end

  def test_register_tools_returns_datamap
    factory = SignalWire::Skills::SkillRegistry.get_factory('datasphere_serverless')
    skill = build_full_skill(factory)
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert tools[0].key?(:datamap)
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('datasphere_serverless')
    skill = build_full_skill(factory, document_id: 'doc1')
    skill.setup
    data = skill.get_global_data

    assert data['datasphere_serverless_enabled']
  end

  private

  # Build a skill instance with the full required-params set.
  def build_full_skill(factory, document_id: 'd')
    factory.call({
                   'space_name' => 'test', 'project_id' => 'p',
                   'token' => 't', 'document_id' => document_id
                 })
  end
end
