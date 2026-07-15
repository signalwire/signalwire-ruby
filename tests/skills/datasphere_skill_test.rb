# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/signalwire/skills/builtin/datasphere'

class DatasphereSkillDetailedTest < Minitest::Test
  include TestHelper::Helpers

  DATASPHERE_ENV = %w[SIGNALWIRE_PROJECT_ID SIGNALWIRE_TOKEN].freeze

  # Each input path of the old test_setup_requires_all_params is now its own
  # method so a failure pinpoints which path broke.
  def test_setup_fails_with_no_params
    without_env_vars(DATASPHERE_ENV) do
      refute build_skill('datasphere').setup,
             'datasphere must fail setup with no params'
    end
  end

  def test_setup_fails_with_partial_params
    without_env_vars(DATASPHERE_ENV) do
      refute build_skill('datasphere', 'space_name' => 'test', 'project_id' => 'p').setup,
             'datasphere must fail setup missing token/document_id'
    end
  end

  def test_setup_succeeds_with_full_params
    without_env_vars(DATASPHERE_ENV) do
      assert build_full_skill.setup,
             'datasphere must set up with the full required-params set'
    end
  end

  def test_register_tools
    skill = build_full_skill
    skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_equal 'search_knowledge', tools[0][:name]
  end

  def test_supports_multiple_instances
    skill = build_skill('datasphere')

    assert_predicate skill, :supports_multiple_instances?
  end

  def test_global_data
    skill = build_full_skill(document_id: 'doc1')
    skill.setup
    data = skill.get_global_data

    assert data['datasphere_enabled']
    assert_equal 'doc1', data['document_id']
  end

  private

  # Build a datasphere skill with the full required-params set.
  def build_full_skill(document_id: 'd')
    build_skill('datasphere',
                'space_name' => 'test', 'project_id' => 'p',
                'token' => 't', 'document_id' => document_id)
  end
end
