# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/info_gatherer'

class InfoGathererSkillDetailedTest < Minitest::Test
  def build_skill_with_questions
    factory = SignalWire::Skills::SkillRegistry.get_factory('info_gatherer')
    factory.call({
                   'questions' => [
                     { 'key_name' => 'name', 'question_text' => 'What is your name?' },
                     { 'key_name' => 'email', 'question_text' => 'What is your email?', 'confirm' => true }
                   ]
                 })
  end

  def test_setup_and_register_tools
    skill = build_skill_with_questions

    assert skill.setup
    tools = skill.register_tools

    assert_equal 2, tools.size
    names = tools.map { |t| t[:name] }

    assert_includes names, 'start_questions'
    assert_includes names, 'submit_answer'
  end

  def test_setup_fails_without_questions
    factory = SignalWire::Skills::SkillRegistry.get_factory('info_gatherer')
    skill = factory.call({})

    refute skill.setup
  end

  def test_setup_fails_with_invalid_questions
    factory = SignalWire::Skills::SkillRegistry.get_factory('info_gatherer')
    skill = factory.call({ 'questions' => [{ 'key_name' => 'x' }] })

    refute skill.setup
  end

  def test_global_data
    factory = SignalWire::Skills::SkillRegistry.get_factory('info_gatherer')
    skill = factory.call({
                           'questions' => [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
                         })
    skill.setup
    data = skill.get_global_data

    assert data.key?('skill:info_gatherer')
    assert_equal 1, data['skill:info_gatherer']['questions'].size
  end

  def test_custom_prefix
    factory = SignalWire::Skills::SkillRegistry.get_factory('info_gatherer')
    skill = factory.call({
                           'questions' => [{ 'key_name' => 'name', 'question_text' => 'Name?' }],
                           'prefix' => 'onboard'
                         })
    skill.setup
    tools = skill.register_tools
    names = tools.map { |t| t[:name] }

    assert_includes names, 'onboard_start_questions'
    assert_includes names, 'onboard_submit_answer'
  end
end
