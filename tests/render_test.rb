# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Shared helpers for poking at rendered SWML in the render tests.
module RenderHelpers
  # The 'ai' verb block from a rendered SWML document's main section.
  def ai_section(swml)
    swml['sections']['main'].find { |v| v.key?('ai') }['ai']
  end
end

class RenderBasicStructureTest < Minitest::Test
  def test_basic_structure
    agent = SignalWire::AgentBase.new
    swml = agent.render_swml

    assert_equal '1.0.0', swml['version']
    assert swml.key?('sections')
    assert swml['sections'].key?('main')
  end

  def test_auto_answer_enabled
    agent = SignalWire::AgentBase.new(auto_answer: true)
    swml = agent.render_swml
    main = swml['sections']['main']

    assert(main.any? { |v| v.key?('answer') })
  end

  def test_auto_answer_disabled
    agent = SignalWire::AgentBase.new(auto_answer: false)
    swml = agent.render_swml
    main = swml['sections']['main']

    refute(main.any? { |v| v.key?('answer') })
  end
end

class RenderRecordCallTest < Minitest::Test
  def test_record_call
    agent = SignalWire::AgentBase.new(record_call: true, record_format: 'wav', record_stereo: false)
    swml = agent.render_swml
    main = swml['sections']['main']
    rec = main.find { |v| v.key?('record_call') }

    assert rec
    assert_equal 'wav', rec['record_call']['format']
    assert_equal false, rec['record_call']['stereo']
  end
end

class RenderWithToolsTest < Minitest::Test
  include RenderHelpers

  def test_tools_rendered
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 'foo', description: 'Foo tool') { |_, _| }
    swml = agent.render_swml
    ai = ai_section(swml)

    assert ai.key?('SWAIG')
    funcs = ai['SWAIG']['functions']

    assert_equal 1, funcs.length
    assert_equal 'foo', funcs[0]['function']
  end
end

class RenderWithPromptTest < Minitest::Test
  include RenderHelpers

  def test_pom_prompt
    agent = SignalWire::AgentBase.new
    agent.prompt_add_section('Intro', 'Hello')
    swml = agent.render_swml
    ai = ai_section(swml)
    pom = ai['prompt']['pom']

    assert_instance_of Array, pom
    assert_equal 'Intro', pom[0]['title']
  end

  def test_text_prompt
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('You are helpful.')
    swml = agent.render_swml
    ai = ai_section(swml)

    assert_equal 'You are helpful.', ai['prompt']['text']
  end
end

class Render5PhaseOrderingTest < Minitest::Test
  # Expected SWML main-section verb order: pre-answer < answer < record_call <
  # post-answer < ai < post-ai.
  EXPECTED_PHASE_ORDER = %w[set answer record_call play ai hangup].freeze

  def five_phase_agent
    agent = SignalWire::AgentBase.new(record_call: true)
    agent.add_pre_answer_verb('set', { 'x' => '1' })
    agent.add_post_answer_verb('play', { 'url' => 'welcome.mp3' })
    agent.add_post_ai_verb('hangup', {})
    agent
  end

  def test_5_phase_ordering
    swml = five_phase_agent.render_swml
    keys = swml['sections']['main'].map { |v| v.keys.first }

    indices = EXPECTED_PHASE_ORDER.map { |verb| keys.index(verb) }

    refute_includes indices, nil, "missing expected verb in #{keys.inspect}"
    assert_equal indices.sort, indices, "verbs out of phase order: #{keys.inspect}"
  end
end

class RenderEdgeCasesTest < Minitest::Test
  include RenderHelpers

  def test_empty_agent_renders
    agent = SignalWire::AgentBase.new
    swml = agent.render_swml

    assert_equal '1.0.0', swml['version']
    main = swml['sections']['main']

    assert(main.any? { |v| v.key?('ai') })
  end

  def test_with_params
    agent = SignalWire::AgentBase.new
    agent.set_params({ 'temperature' => 0.5 })
    swml = agent.render_swml
    ai = ai_section(swml)

    assert_in_delta(0.5, ai['params']['temperature'])
  end

  def test_contexts_rendered_in_swml
    agent = SignalWire::AgentBase.new
    ctx = agent.define_contexts.add_context('default')
    ctx.add_step('greeting').set_text('Say hello')
    swml = agent.render_swml
    ai = ai_section(swml)

    assert ai.key?('contexts'), 'Expected contexts in AI config'
    assert ai['contexts'].key?('default')
  end
end
