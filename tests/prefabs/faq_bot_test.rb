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
end
