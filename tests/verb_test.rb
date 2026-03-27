# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class PreAnswerVerbTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_pre_answer_verbs
    @agent.add_pre_answer_verb('play', { 'url' => 'https://example.com/ring.mp3' })
    swml = @agent.render_swml
    main = swml['sections']['main']
    first = main[0]
    assert first.key?('play')
    assert_equal 'https://example.com/ring.mp3', first['play']['url']
  end

  def test_clear_pre_answer_verbs
    @agent.add_pre_answer_verb('play', { 'url' => 'ring.mp3' })
    @agent.clear_pre_answer_verbs
    swml = @agent.render_swml
    main = swml['sections']['main']
    assert_equal 'answer', main[0].keys.first
  end

  def test_multiple_pre_answer_verbs
    @agent.add_pre_answer_verb('set', { 'x' => '1' })
    @agent.add_pre_answer_verb('play', { 'url' => 'ring.mp3' })
    swml = @agent.render_swml
    main = swml['sections']['main']
    assert main[0].key?('set')
    assert main[1].key?('play')
  end
end

class PostAnswerVerbTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_post_answer_verbs
    @agent.add_post_answer_verb('play', { 'url' => 'welcome.mp3' })
    swml = @agent.render_swml
    main = swml['sections']['main']
    answer_idx = main.index { |v| v.key?('answer') }
    ai_idx     = main.index { |v| v.key?('ai') }
    play_idx   = main.index { |v| v.key?('play') }
    assert play_idx > answer_idx
    assert play_idx < ai_idx
  end

  def test_clear_post_answer_verbs
    @agent.add_post_answer_verb('play', {})
    @agent.clear_post_answer_verbs
    swml = @agent.render_swml
    main = swml['sections']['main']
    refute main.any? { |v| v.key?('play') }
  end
end

class PostAiVerbTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_post_ai_verbs
    @agent.add_post_ai_verb('hangup', {})
    swml = @agent.render_swml
    main = swml['sections']['main']
    ai_idx     = main.index { |v| v.key?('ai') }
    hangup_idx = main.index { |v| v.key?('hangup') }
    assert hangup_idx > ai_idx
  end

  def test_clear_post_ai_verbs
    @agent.add_post_ai_verb('hangup', {})
    @agent.clear_post_ai_verbs
    swml = @agent.render_swml
    main = swml['sections']['main']
    refute main.any? { |v| v.key?('hangup') }
  end
end

class AnswerVerbConfigTest < Minitest::Test
  def test_answer_verb_config
    agent = SignalWire::AgentBase.new
    agent.add_answer_verb({ 'max_duration' => 3600 })
    swml = agent.render_swml
    main = swml['sections']['main']
    answer = main.find { |v| v.key?('answer') }
    assert_equal 3600, answer['answer']['max_duration']
  end
end

class VerbChainingTest < Minitest::Test
  def test_all_verb_methods_return_self
    agent = SignalWire::AgentBase.new
    assert_same agent, agent.add_pre_answer_verb('play', {})
    assert_same agent, agent.clear_pre_answer_verbs
    assert_same agent, agent.add_answer_verb({})
    assert_same agent, agent.add_post_answer_verb('play', {})
    assert_same agent, agent.clear_post_answer_verbs
    assert_same agent, agent.add_post_ai_verb('hangup', {})
    assert_same agent, agent.clear_post_ai_verbs
  end
end
