# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/prefabs/info_gatherer'

class InfoGathererPrefabDetailedTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [
        { 'key_name' => 'name', 'question_text' => 'What is your name?' },
        { 'key_name' => 'email', 'question_text' => 'What is your email?' }
      ]
    )
    assert_equal 'info_gatherer', agent.name
    assert_equal '/info_gatherer', agent.route
    assert_equal 2, agent.questions.size
  end

  def test_tools
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    assert_includes agent.tools, 'start_questions'
    assert_includes agent.tools, 'submit_answer'
  end

  def test_handle_start
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'What is your name?' }]
    )
    result = agent.handle_start({}, {})
    assert_match(/What is your name/, result.response)
  end

  def test_handle_submit
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    result = agent.handle_submit({ 'answer' => 'Alice' }, {})
    assert_includes result.response, 'Alice'
  end

  def test_raises_without_questions
    assert_raises(ArgumentError) { SignalWire::Prefabs::InfoGatherer.new(questions: []) }
  end

  def test_prompt_sections
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    sections = agent.prompt_sections
    assert_equal 1, sections.size
    assert_equal 'Info Gatherer', sections[0]['title']
  end

  def test_global_data
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    data = agent.global_data
    assert data.key?('info_gatherer')
    assert_equal 0, data['info_gatherer']['question_index']
  end

  def test_custom_name_and_route
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }],
      name: 'custom', route: '/custom'
    )
    assert_equal 'custom', agent.name
    assert_equal '/custom', agent.route
  end
end
