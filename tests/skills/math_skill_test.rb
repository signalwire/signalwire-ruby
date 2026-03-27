# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/skills/skill_base'
require_relative '../../lib/signalwire/skills/skill_registry'
require_relative '../../lib/signalwire/skills/builtin/math'

class MathSkillDetailedTest < Minitest::Test
  def setup
    factory = SignalWire::Skills::SkillRegistry.get_factory('math')
    @skill = factory.call({})
    @skill.setup
    @calc = @skill.register_tools[0][:handler]
  end

  def test_name_and_description
    assert_equal 'math', @skill.name
    assert_equal 'Perform basic mathematical calculations', @skill.description
  end

  def test_register_tools_returns_one_tool
    tools = @skill.register_tools
    assert_equal 1, tools.size
    assert_equal 'calculate', tools[0][:name]
  end

  def test_addition
    result = @calc.call({ 'expression' => '2 + 3' }, {})
    assert_match(/= 5/, result.response)
  end

  def test_multiplication
    result = @calc.call({ 'expression' => '4 * 7' }, {})
    assert_match(/= 28/, result.response)
  end

  def test_complex_expression
    result = @calc.call({ 'expression' => '(10 + 5) / 3' }, {})
    assert_match(/= 5/, result.response)
  end

  def test_power
    result = @calc.call({ 'expression' => '2 ** 10' }, {})
    assert_match(/= 1024/, result.response)
  end

  def test_modulo
    result = @calc.call({ 'expression' => '17 % 5' }, {})
    assert_match(/= 2/, result.response)
  end

  def test_division_by_zero
    result = @calc.call({ 'expression' => '5 / 0' }, {})
    assert_match(/division by zero/i, result.response)
  end

  def test_invalid_expression
    result = @calc.call({ 'expression' => 'hello world' }, {})
    assert_match(/error/i, result.response)
  end

  def test_empty_expression
    result = @calc.call({ 'expression' => '' }, {})
    assert_match(/provide/i, result.response)
  end

  def test_prompt_sections
    sections = @skill.get_prompt_sections
    assert_equal 1, sections.size
    assert_equal 'Mathematical Calculations', sections[0]['title']
  end
end
