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

# ---------------------------------------------------------------------------
# Python parity: brand_name / max_retries
# ---------------------------------------------------------------------------
class SurveyPrefabBrandRetriesTest < Minitest::Test
  def survey(**)
    SignalWire::Prefabs::Survey.new(
      survey_name: 'Test', questions: [{ 'id' => 'q1', 'text' => 'Q?' }], **
    )
  end

  def prompt_blob(agent)
    agent.prompt_sections.map { |s| [s['title'], s['body'], *(s['bullets'] || [])].join(' ') }.join(' ')
  end

  def test_default_brand_name
    assert_equal 'Our Company', survey.brand_name
  end

  def test_custom_brand_name
    assert_equal 'WidgetCorp', survey(brand_name: 'WidgetCorp').brand_name
  end

  def test_default_max_retries
    assert_equal 2, survey.max_retries
  end

  def test_max_retries_setting
    assert_equal 5, survey(max_retries: 5).max_retries
  end

  # brand_name reaches the model through the personality prompt section
  def test_brand_name_in_prompt_sections
    assert_includes prompt_blob(survey(brand_name: 'WidgetCorp')), 'WidgetCorp'
  end

  # max_retries reaches the model through the retry instruction bullet
  def test_max_retries_in_prompt_sections
    assert_includes prompt_blob(survey(max_retries: 5)), 'retry up to 5 times'
  end

  def test_brand_name_and_max_retries_in_global_data
    data = survey(brand_name: 'WidgetCorp', max_retries: 5).global_data

    assert_equal 'WidgetCorp', data['brand_name']
    assert_equal 5, data['max_retries']
  end
end
