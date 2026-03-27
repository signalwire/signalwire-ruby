# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/datamap/data_map'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/datasphere_serverless'

class DatasphereServerlessSkillDetailedTest < Minitest::Test
  def test_setup_requires_all_params
    saved = %w[SIGNALWIRE_PROJECT_ID SIGNALWIRE_TOKEN].map { |k| [k, ENV.delete(k)] }.to_h
    begin
      factory = SignalWire::Skills::SkillRegistry.get_factory('datasphere_serverless')
      skill = factory.call({})
      refute skill.setup

      skill_full = factory.call({
        'space_name' => 'test', 'project_id' => 'p',
        'token' => 't', 'document_id' => 'd'
      })
      assert skill_full.setup
    ensure
      saved.each { |k, v| ENV[k] = v if v }
    end
  end

  def test_register_tools_returns_datamap
    factory = SignalWire::Skills::SkillRegistry.get_factory('datasphere_serverless')
    skill = factory.call({
      'space_name' => 'test', 'project_id' => 'p',
      'token' => 't', 'document_id' => 'd'
    })
    skill.setup
    tools = skill.register_tools
    assert_equal 1, tools.size
    assert tools[0].key?(:datamap)
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('datasphere_serverless')
    skill = factory.call({
      'space_name' => 'test', 'project_id' => 'p',
      'token' => 't', 'document_id' => 'doc1'
    })
    skill.setup
    data = skill.get_global_data
    assert_equal true, data['datasphere_serverless_enabled']
  end
end
