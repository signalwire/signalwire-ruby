# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class PromptManagerTest < Minitest::Test
  def setup
    @pm = SignalWire::Core::Agent::Prompt::PromptManager.new
  end

  def test_set_prompt_text_and_get
    @pm.set_prompt_text('You are helpful.')

    assert_equal 'You are helpful.', @pm.get_prompt
    assert_equal 'You are helpful.', @pm.get_raw_prompt
  end

  def test_post_prompt
    @pm.set_post_prompt('Summarize the call')

    assert_equal 'Summarize the call', @pm.get_post_prompt
  end

  def test_prompt_add_section_builds_pom_array
    @pm.prompt_add_section('Personality', body: 'Be helpful')
    @pm.prompt_add_section('Rules', bullets: ['Be concise', 'Be accurate'])
    prompt = @pm.get_prompt

    assert_instance_of Array, prompt
    assert_equal 2, prompt.length
    assert_equal 'Personality', prompt[0]['title']
    assert_equal 'Be helpful', prompt[0]['body']
    assert_equal ['Be concise', 'Be accurate'], prompt[1]['bullets']
  end

  def test_prompt_add_to_section_appends_body
    @pm.prompt_add_section('Intro', body: 'Hello')
    @pm.prompt_add_to_section('Intro', body: 'World')

    assert_equal "Hello\n\nWorld", @pm.get_prompt[0]['body']
  end

  def test_prompt_add_to_section_creates_when_absent
    @pm.prompt_add_to_section('New', bullet: 'first')
    section = @pm.get_prompt[0]

    assert_equal 'New', section['title']
    assert_equal ['first'], section['bullets']
  end

  def test_prompt_add_subsection
    @pm.prompt_add_section('Main', body: 'Top')
    @pm.prompt_add_subsection('Main', 'Sub', body: 'Sub body', bullets: %w[a b])
    sub = @pm.get_prompt[0]['subsections'][0]

    assert_equal 'Sub', sub['title']
    assert_equal 'Sub body', sub['body']
    assert_equal %w[a b], sub['bullets']
  end

  def test_prompt_add_subsection_creates_parent
    @pm.prompt_add_subsection('Parent', 'Child', body: 'b')
    section = @pm.get_prompt[0]

    assert_equal 'Parent', section['title']
    assert_equal 'Child', section['subsections'][0]['title']
  end

  def test_prompt_has_section
    @pm.prompt_add_section('Foo', body: 'bar')

    assert @pm.prompt_has_section('Foo')
    refute @pm.prompt_has_section('Baz')
  end

  def test_set_prompt_pom
    @pm.set_prompt_pom([{ 'title' => 'Intro', 'body' => 'Hi' }])

    assert @pm.prompt_has_section('Intro')
    assert_equal 'Intro', @pm.get_prompt[0]['title']
  end

  def test_get_prompt_nil_when_empty
    assert_nil @pm.get_prompt
  end

  # Mode exclusivity mirrors Python: the guard fires only when raw text is
  # ALREADY set AND at least one POM section already exists. The guard is
  # asymmetric — it inspects @prompt_text, so building POM first then
  # setting text does NOT raise (Python's set_prompt_text has the same
  # asymmetry).
  def test_mode_exclusivity_section_while_text_set_raises
    @pm.set_prompt_text('raw')
    # First section: text set but POM empty → allowed (matches Python).
    @pm.prompt_add_section('S1', body: 'b')

    # Second section: text set AND POM non-empty → raises.
    assert_raises(ArgumentError) { @pm.prompt_add_section('S2', body: 'b') }
  end

  # Building POM first then setting text does not raise (asymmetric guard).
  def test_pom_then_text_does_not_raise
    @pm.prompt_add_section('Sec', body: 'b')

    @pm.set_prompt_text('raw') # no raise — @prompt_text was nil at check time

    assert_equal 'raw', @pm.get_raw_prompt
  end

  def test_define_contexts_from_builder
    cb = SignalWire::Contexts::ContextBuilder.new
    cb.add_context('default').add_step('greeting').set_text('Say hello')
    @pm.define_contexts(cb)
    contexts = @pm.get_contexts

    assert_kind_of Hash, contexts
    assert contexts.key?('default')
  end

  def test_define_contexts_from_hash
    @pm.define_contexts({ 'default' => { 'steps' => [] } })

    assert @pm.get_contexts.key?('default')
  end

  def test_define_contexts_invalid_raises
    assert_raises(ArgumentError) { @pm.define_contexts('nope') }
  end

  def test_contexts_take_precedence_in_get_prompt
    @pm.prompt_add_section('Sec', body: 'b')
    cb = SignalWire::Contexts::ContextBuilder.new
    cb.add_context('default').add_step('s').set_text('go')
    @pm.define_contexts(cb)

    assert_nil @pm.get_prompt, 'contexts should take precedence and suppress prompt'
  end

  def test_returns_self_for_chaining
    assert_same @pm, @pm.set_prompt_text('x')
    assert_same @pm, @pm.set_post_prompt('x')

    pm2 = SignalWire::Core::Agent::Prompt::PromptManager.new

    assert_same pm2, pm2.prompt_add_section('T', body: 'b')
    assert_same pm2, pm2.prompt_add_to_section('T', body: 'more')
    assert_same pm2, pm2.prompt_add_subsection('T', 'S', body: 'b')
  end
end
