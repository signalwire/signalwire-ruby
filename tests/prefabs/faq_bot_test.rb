# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/prefabs/faq_bot'

class FaqBotPrefabDetailedTest < Minitest::Test
  def test_construction
    agent = SignalWire::Prefabs::FaqBot.new(
      faqs: [{ 'question' => 'What is SignalWire?', 'answer' => 'A communications platform.' }]
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

  def test_handle_search_match
    agent = SignalWire::Prefabs::FaqBot.new(
      faqs: [{ 'question' => 'What is SignalWire?', 'answer' => 'A cloud comms platform.' }]
    )
    result = agent.handle_search({ 'query' => 'signalwire' }, {})

    assert_match(/cloud comms/i, result.response)
  end

  def test_handle_search_no_match
    agent = SignalWire::Prefabs::FaqBot.new(
      faqs: [{ 'question' => 'What is SignalWire?', 'answer' => 'A platform.' }]
    )
    result = agent.handle_search({ 'query' => 'banana' }, {})

    assert_includes result.response, 'topics'
  end

  def test_raises_without_faqs
    assert_raises(ArgumentError) { SignalWire::Prefabs::FaqBot.new(faqs: []) }
  end

  def test_global_data
    agent = SignalWire::Prefabs::FaqBot.new(
      faqs: [{ 'question' => 'Q?', 'answer' => 'A.' }]
    )
    data = agent.global_data

    assert data.key?('faqs')
  end

  # ---- caller-supplied config is readable back AND reaches the prompt --------

  def faqs = [{ 'question' => 'Q?', 'answer' => 'A.' }]

  def test_persona_readable_back
    agent = SignalWire::Prefabs::FaqBot.new(faqs: faqs, persona: 'You are terse.')

    assert_equal 'You are terse.', agent.persona
  end

  def test_persona_defaults_and_is_readable
    agent = SignalWire::Prefabs::FaqBot.new(faqs: faqs)

    assert_includes agent.persona, 'FAQ bot'
  end

  def test_suggest_related_readable_back
    assert SignalWire::Prefabs::FaqBot.new(faqs: faqs).suggest_related
    refute SignalWire::Prefabs::FaqBot.new(faqs: faqs, suggest_related: false).suggest_related
  end

  # suggest_related is the switch that tells the agent to offer related
  # questions. Storing it in global_data alone left it with no effect on agent
  # behaviour; the reference renders it into the prompt (faq_bot.py:110,143-148).
  def test_suggest_related_reaches_the_prompt_when_on
    sections = SignalWire::Prefabs::FaqBot.new(faqs: faqs, suggest_related: true).prompt_sections
    section = sections.find { |s| s['title'] == 'Related Questions' }

    refute_nil section, 'suggest_related: true must reach the rendered prompt'
    assert_includes section['body'], 'related questions'
  end

  def test_suggest_related_absent_from_the_prompt_when_off
    sections = SignalWire::Prefabs::FaqBot.new(faqs: faqs, suggest_related: false).prompt_sections

    assert_nil(sections.find { |s| s['title'] == 'Related Questions' })
  end
end
