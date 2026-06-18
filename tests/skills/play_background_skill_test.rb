# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/play_background_file'

class PlayBackgroundSkillDetailedTest < Minitest::Test
  def test_setup_and_register
    factory = SignalWire::Skills::SkillRegistry.get_factory('play_background_file')
    skill = factory.call({
                           'files' => [
                             { 'key' => 'music1', 'description' => 'Background music', 'url' => 'https://example.com/music.mp3' }
                           ]
                         })

    assert skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_operator tools[0][:datamap]['data_map']['expressions'].size, :>=, 2
  end

  def test_setup_fails_without_files
    factory = SignalWire::Skills::SkillRegistry.get_factory('play_background_file')
    skill = factory.call({})

    refute skill.setup
  end

  def test_setup_fails_with_invalid_files
    factory = SignalWire::Skills::SkillRegistry.get_factory('play_background_file')
    skill = factory.call({ 'files' => [{ 'key' => 'x' }] })

    refute skill.setup
  end

  def test_expressions_include_start_and_stop
    factory = SignalWire::Skills::SkillRegistry.get_factory('play_background_file')
    files = [{ 'key' => 'bgm', 'description' => 'BGM', 'url' => 'https://example.com/bgm.mp3' }]
    skill = factory.call({ 'files' => files })
    skill.setup
    exprs = skill.register_tools[0].dig(:datamap, 'data_map', 'expressions')
    patterns = exprs.map { |e| e['pattern'] }

    assert(patterns.any? { |p| p.include?('start_bgm') })
    assert(patterns.any? { |p| p.include?('stop') })
  end
end
