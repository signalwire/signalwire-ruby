# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class PromptTextModeTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_set_prompt_text
    @agent.set_prompt_text('Hello world')
    assert_equal 'Hello world', @agent.get_prompt
  end

  def test_text_mode_returns_string
    @agent.set_prompt_text('Raw text')
    assert_instance_of String, @agent.get_prompt
  end

  def test_text_mode_clears_pom
    @agent.prompt_add_section('Sec', 'body')
    @agent.set_prompt_text('Raw text')
    assert_equal 'Raw text', @agent.get_prompt
  end

  def test_text_mode_renders_in_swml
    @agent.set_prompt_text('You are helpful.')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 'You are helpful.', ai['prompt']['text']
  end

  def test_empty_prompt_returns_nil
    agent = SignalWire::AgentBase.new
    assert_nil agent.get_prompt
  end
end

class PromptPomModeTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_set_prompt_pom_direct
    pom = [{ 'title' => 'Intro', 'body' => 'Hi' }]
    @agent.set_prompt_pom(pom)
    assert_equal pom, @agent.get_prompt
  end

  def test_pom_mode_clears_text
    @agent.set_prompt_text('Raw text')
    @agent.prompt_add_section('Sec', 'body')
    prompt = @agent.get_prompt
    assert_instance_of Array, prompt
    assert_equal 'Sec', prompt[0]['title']
  end

  def test_pom_renders_in_swml
    @agent.prompt_add_section('Intro', 'Hello')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    pom = ai['prompt']['pom']
    assert_instance_of Array, pom
    assert_equal 'Intro', pom[0]['title']
  end
end

class PromptSectionTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_add_section_basic
    @agent.prompt_add_section('Personality', 'Be helpful')
    prompt = @agent.get_prompt
    assert_equal 1, prompt.length
    assert_equal 'Personality', prompt[0]['title']
    assert_equal 'Be helpful', prompt[0]['body']
  end

  def test_add_section_with_bullets
    @agent.prompt_add_section('Rules', nil, bullets: ['Be concise', 'Be accurate'])
    prompt = @agent.get_prompt
    assert_equal ['Be concise', 'Be accurate'], prompt[0]['bullets']
  end

  def test_multiple_sections
    @agent.prompt_add_section('A', 'Body A')
    @agent.prompt_add_section('B', 'Body B')
    prompt = @agent.get_prompt
    assert_equal 2, prompt.length
  end

  def test_add_to_section
    @agent.prompt_add_section('Intro', 'Hello')
    @agent.prompt_add_to_section('Intro', ' World')
    prompt = @agent.get_prompt
    assert_equal 'Hello World', prompt[0]['body']
  end

  def test_add_to_nonexistent_section_is_noop
    @agent.prompt_add_section('A', 'Body')
    @agent.prompt_add_to_section('NonExistent', ' extra')
    prompt = @agent.get_prompt
    assert_equal 1, prompt.length
  end

  def test_add_subsection
    @agent.prompt_add_section('Main', 'Top-level body')
    @agent.prompt_add_subsection('Main', 'Sub', 'Sub body', bullets: ['a', 'b'])
    prompt = @agent.get_prompt
    assert_equal 1, prompt[0]['subsections'].length
    assert_equal 'Sub', prompt[0]['subsections'][0]['title']
    assert_equal 'Sub body', prompt[0]['subsections'][0]['body']
    assert_equal ['a', 'b'], prompt[0]['subsections'][0]['bullets']
  end

  def test_has_section
    @agent.prompt_add_section('Foo', 'bar')
    assert @agent.prompt_has_section?('Foo')
    refute @agent.prompt_has_section?('Baz')
  end
end

class PromptPostPromptTest < Minitest::Test
  def test_post_prompt_renders
    agent = SignalWire::AgentBase.new
    agent.set_post_prompt('Summarize the call')
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_equal 'Summarize the call', ai['post_prompt']['text']
  end

  def test_post_prompt_url_generated
    agent = SignalWire::AgentBase.new(basic_auth: ['u', 'p'])
    agent.set_post_prompt('Summarize')
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    assert_includes ai['post_prompt_url'], '/post_prompt'
  end
end

class PromptChainingTest < Minitest::Test
  def test_all_prompt_methods_return_self
    agent = SignalWire::AgentBase.new
    assert_same agent, agent.set_prompt_text('x')
    assert_same agent, agent.set_post_prompt('x')
    assert_same agent, agent.set_prompt_pom([])
    assert_same agent, agent.prompt_add_section('T', 'B')
    assert_same agent, agent.prompt_add_to_section('T', 'x')
    assert_same agent, agent.prompt_add_subsection('T', 'S', 'B')
  end
end

# ----------------------------------------------------------------------
# pom accessor (Python parity: agent.pom)
#
# Mirrors signalwire-python tests/unit/core/test_agent_base.py::
#   TestAgentBasePromptMethods::test_set_prompt_pom_succeeds_when_use_pom_true
# ----------------------------------------------------------------------
class PomAccessorTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_pom_returns_assigned_sections
    sections = [{ 'title' => 'Greeting', 'body' => 'Hello' }]
    @agent.set_prompt_pom(sections)
    pom = @agent.pom
    refute_nil pom
    assert_equal 1, pom.length
    assert_equal 'Greeting', pom[0]['title']
    assert_equal 'Hello', pom[0]['body']
  end

  def test_pom_returns_sections_after_prompt_add_section
    @agent.prompt_add_section('Topic', 'Body text')
    pom = @agent.pom
    refute_nil pom
    assert_equal 1, pom.length
    assert_equal 'Topic', pom[0]['title']
    assert_equal 'Body text', pom[0]['body']
  end

  def test_pom_nil_when_in_text_mode
    # set_prompt_text disables POM mode; pom must return nil to mirror
    # Python's "self.pom is None when use_pom is False".
    @agent.set_prompt_text('plain text')
    assert_nil @agent.pom
  end

  def test_pom_returns_copy_not_internal_array
    @agent.prompt_add_section('Original', 'Body')
    pom = @agent.pom
    refute_nil pom

    # Mutate the returned array; internal state must be unchanged.
    pom << { 'title' => 'Injected' }
    pom[0]['title'] = 'Hijacked'

    fresh = @agent.pom
    assert_equal 1, fresh.length, 'caller mutation leaked into agent state'
    assert_equal 'Original', fresh[0]['title'], 'caller mutation leaked into agent state'
  end
end
