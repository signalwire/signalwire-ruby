# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/prefabs/survey'

class SurveyPrefabDetailedTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::Survey.new(
      survey_name: 'Satisfaction Survey',
      questions: [
        { 'id' => 'rating', 'text' => 'How would you rate us?', 'type' => 'rating', 'scale' => 5 }
      ]
    )
    assert_equal 'survey', agent.name
    assert_equal 'Satisfaction Survey', agent.survey_name
    assert_equal 1, agent.questions.size
  end

  def test_tools
    agent = SignalWire::Prefabs::Survey.new(
      survey_name: 'Test', questions: [{ 'id' => 'q1', 'text' => 'Question?' }]
    )
    assert_includes agent.tools, 'start_survey'
    assert_includes agent.tools, 'submit_survey_answer'
    assert_includes agent.tools, 'get_survey_summary'
  end

  def test_handle_start
    agent = SignalWire::Prefabs::Survey.new(
      survey_name: 'Test', questions: [{ 'id' => 'q1', 'text' => 'How was it?' }]
    )
    result = agent.handle_start({}, {})
    assert_includes result.response, 'How was it?'
  end

  def test_handle_submit
    agent = SignalWire::Prefabs::Survey.new(
      survey_name: 'Test', questions: [{ 'id' => 'q1', 'text' => 'Q?' }]
    )
    result = agent.handle_submit({ 'answer' => 'Great' }, {})
    assert_includes result.response, 'Great'
  end

  def test_handle_summary
    agent = SignalWire::Prefabs::Survey.new(
      survey_name: 'Test', questions: [{ 'id' => 'q1', 'text' => 'Q?' }],
      conclusion: 'All done!'
    )
    result = agent.handle_summary({}, {})
    assert_equal 'All done!', result.response
  end

  def test_global_data
    agent = SignalWire::Prefabs::Survey.new(
      survey_name: 'Test', questions: [{ 'id' => 'q1', 'text' => 'Q?' }]
    )
    data = agent.global_data
    assert data.key?('survey')
    assert_equal 'Test', data['survey']['name']
  end

  def test_raises_without_questions
    assert_raises(ArgumentError) do
      SignalWire::Prefabs::Survey.new(survey_name: 'Test', questions: [])
    end
  end
end
