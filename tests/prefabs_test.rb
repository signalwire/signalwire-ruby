# frozen_string_literal: true

require 'minitest/autorun'

require_relative '../lib/signalwire/swaig/function_result'
require_relative '../lib/signalwire/prefabs/info_gatherer'
require_relative '../lib/signalwire/prefabs/survey'
require_relative '../lib/signalwire/prefabs/receptionist'
require_relative '../lib/signalwire/prefabs/faq_bot'
require_relative '../lib/signalwire/prefabs/concierge'

class InfoGathererPrefabTest < Minitest::Test
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

  def test_raises_without_questions
    assert_raises(ArgumentError) { SignalWire::Prefabs::InfoGatherer.new(questions: []) }
  end
end

class SurveyPrefabTest < Minitest::Test
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
      survey_name: 'Test',
      questions: [{ 'id' => 'q1', 'text' => 'Question?' }]
    )

    assert_includes agent.tools, 'start_survey'
    assert_includes agent.tools, 'submit_survey_answer'
    assert_includes agent.tools, 'get_survey_summary'
  end
end

class ReceptionistPrefabTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [
        { 'name' => 'sales', 'description' => 'Sales dept', 'number' => '+15551235555' }
      ]
    )

    assert_equal 'receptionist', agent.name
    assert_equal 1, agent.departments.size
  end

  def test_tools
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [
        { 'name' => 'sales', 'description' => 'Sales', 'number' => '+15551235555' }
      ]
    )

    assert_includes agent.tools, 'transfer_to_department'
    assert_includes agent.tools, 'collect_caller_info'
  end

  def test_handle_transfer
    agent = SignalWire::Prefabs::Receptionist.new(
      departments: [
        { 'name' => 'sales', 'description' => 'Sales', 'number' => '+15551235555' }
      ]
    )
    result = agent.handle_transfer({ 'department' => 'sales' }, {})

    assert_match(/transferring/i, result.response)
  end

  def test_raises_without_departments
    assert_raises(ArgumentError) { SignalWire::Prefabs::Receptionist.new(departments: []) }
  end
end

class FaqBotPrefabTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::FaqBot.new(
      faqs: [
        { 'question' => 'What is SignalWire?', 'answer' => 'A communications platform.' }
      ]
    )

    assert_equal 'faq_bot', agent.name
    assert_equal 1, agent.faqs.size
  end

  def test_tools
    agent = SignalWire::Prefabs::FaqBot.new(
      faqs: [{ 'question' => 'Q?', 'answer' => 'A.' }]
    )

    assert_includes agent.tools, 'search_faq'
  end

  def test_handle_search
    agent = SignalWire::Prefabs::FaqBot.new(
      faqs: [{ 'question' => 'What is SignalWire?', 'answer' => 'A cloud comms platform.' }]
    )
    result = agent.handle_search({ 'query' => 'signalwire' }, {})

    assert_match(/cloud comms/i, result.response)
  end
end

class ConciergePrefabTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Grand Hotel',
      services: ['room service', 'spa'],
      amenities: { 'pool' => { 'hours' => '7 AM - 10 PM' } }
    )

    assert_equal 'concierge', agent.name
    assert_equal 'Grand Hotel', agent.venue_name
    assert_equal 2, agent.services.size
  end

  def test_tools
    agent = SignalWire::Prefabs::Concierge.new(
      venue_name: 'Test',
      services: ['test'],
      amenities: {}
    )

    assert_includes agent.tools, 'get_amenity_info'
    assert_includes agent.tools, 'get_service_info'
  end
end
