# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/datamap/data_map'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/swml_transfer'

class SwmlTransferSkillDetailedTest < Minitest::Test
  def test_setup_and_register
    factory = SignalWire::Skills::SkillRegistry.get_factory('swml_transfer')
    skill = factory.call({
                           'transfers' => {
                             'sales' => { 'url' => 'https://example.com/sales', 'message' => 'Transferring to sales' },
                             'support' => { 'address' => '+15551234567', 'message' => 'Connecting to support' }
                           }
                         })

    assert skill.setup
    tools = skill.register_tools

    assert_equal 1, tools.size
    assert_operator tools[0][:datamap]['data_map']['expressions'].size, :>=, 3
  end

  def test_setup_fails_without_transfers
    factory = SignalWire::Skills::SkillRegistry.get_factory('swml_transfer')
    skill = factory.call({})

    refute skill.setup
  end

  def test_setup_fails_with_empty_transfers
    factory = SignalWire::Skills::SkillRegistry.get_factory('swml_transfer')
    skill = factory.call({ 'transfers' => {} })

    refute skill.setup
  end

  def test_get_hints
    factory = SignalWire::Skills::SkillRegistry.get_factory('swml_transfer')
    skill = factory.call({
                           'transfers' => { 'sales' => { 'url' => 'https://example.com/sales' } }
                         })
    skill.setup
    hints = skill.get_hints

    assert_includes hints, 'transfer'
  end

  def test_prompt_sections
    factory = SignalWire::Skills::SkillRegistry.get_factory('swml_transfer')
    skill = factory.call({
                           'transfers' => { 'sales' => { 'url' => 'https://example.com/sales' } }
                         })
    skill.setup
    sections = skill.get_prompt_sections

    assert_operator sections.size, :>=, 1
  end
end
