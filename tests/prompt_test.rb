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

  def test_add_to_nonexistent_section_creates_it
    # Python parity: ``prompt_add_to_section`` creates the section
    # when it doesn't exist (PromptManager#prompt_add_to_section in
    # signalwire-python). The previous Ruby behaviour silently
    # dropped the call; we now match Python.
    @agent.prompt_add_section('A', 'Body')
    @agent.prompt_add_to_section('NonExistent', ' extra')
    prompt = @agent.get_prompt

    assert_equal 2, prompt.length
    new_sec = prompt.find { |s| s['title'] == 'NonExistent' }

    refute_nil new_sec
    assert_equal ' extra', new_sec['body']
  end

  def test_add_subsection
    @agent.prompt_add_section('Main', 'Top-level body')
    @agent.prompt_add_subsection('Main', 'Sub', 'Sub body', bullets: %w[a b])
    subsections = @agent.get_prompt[0]['subsections']

    assert_equal 1, subsections.length
    assert_equal 'Sub', subsections[0]['title']
    assert_equal 'Sub body', subsections[0]['body']
    assert_equal %w[a b], subsections[0]['bullets']
  end

  def test_has_section
    @agent.prompt_add_section('Foo', 'bar')

    assert @agent.prompt_has_section?('Foo')
    refute @agent.prompt_has_section?('Baz')
  end

  # --- Python parity: prompt_add_section numbered / numbered_bullets / subsections
  def test_add_section_numbered
    @agent.prompt_add_section('Steps', 'Procedure', numbered: true)
    sec = @agent.get_prompt.first

    assert sec['numbered']
  end

  def test_add_section_numbered_bullets
    @agent.prompt_add_section('Steps', 'Procedure', bullets: %w[a b c], numbered_bullets: true)
    sec = @agent.get_prompt.first

    assert sec['numbered_bullets']
  end

  def test_add_section_with_subsections_kwarg
    @agent.prompt_add_section(
      'Main', 'Body',
      subsections: [{ 'title' => 'Sub1', 'body' => 'b1' },
                    { 'title' => 'Sub2', 'bullets' => %w[x y] }]
    )
    subs = @agent.get_prompt.first['subsections']

    assert_equal 2, subs.length
    assert_equal 'Sub1', subs[0]['title']
    assert_equal 'b1',   subs[0]['body']
    assert_equal %w[x y], subs[1]['bullets']
  end

  # --- Python parity: prompt_add_to_section bullet:, bullets:, body: kwargs
  def test_add_to_section_with_single_bullet_kwarg
    @agent.prompt_add_section('Tips', 'Body')
    @agent.prompt_add_to_section('Tips', bullet: 'be polite')
    sec = @agent.get_prompt.first

    assert_equal ['be polite'], sec['bullets']
  end

  def test_add_to_section_with_bullets_array_kwarg
    @agent.prompt_add_section('Tips', 'Body')
    @agent.prompt_add_to_section('Tips', bullets: %w[a b])
    sec = @agent.get_prompt.first

    assert_equal %w[a b], sec['bullets']
  end

  def test_add_to_section_with_body_kwarg_appends
    @agent.prompt_add_section('Intro', 'Hello')
    @agent.prompt_add_to_section('Intro', body: ' world')
    sec = @agent.get_prompt.first

    assert_equal 'Hello world', sec['body']
  end
end

# Python parity: ``define_contexts(contexts)`` accepts a builder, hash,
# or no args (returns the existing builder).
class DefineContextsTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_define_contexts_zero_arg_returns_builder
    cb = @agent.define_contexts

    assert_kind_of SignalWire::Contexts::ContextBuilder, cb
  end

  def test_define_contexts_replaces_with_builder
    cb1 = @agent.define_contexts
    cb2 = SignalWire::Contexts::ContextBuilder.new(@agent)
    @agent.define_contexts(cb2)

    refute_same cb1, @agent.define_contexts
    assert_same cb2, @agent.define_contexts
  end

  def test_define_contexts_accepts_hash
    @agent.define_contexts('default' => { 'steps' => [{ 'name' => 'greet', 'text' => 'hi' }] })
    ctx = @agent.define_contexts.get_context('default')

    refute_nil ctx
    refute_nil ctx.get_step('greet')
  end

  def test_define_contexts_rejects_unknown_arg
    assert_raises(ArgumentError) { @agent.define_contexts(42) }
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
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p])
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
#
# Python's ``agent.pom`` is a ``signalwire.pom.pom.PromptObjectModel``
# instance. The Ruby port returns the equivalent
# ``SignalWire::POM::PromptObjectModel``. To get the legacy array of
# section hashes back out, call ``agent.pom.to_h``.
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
    assert_kind_of SignalWire::POM::PromptObjectModel, pom
    as_h = pom.to_h

    assert_equal 1, as_h.length
    assert_equal 'Greeting', as_h[0]['title']
    assert_equal 'Hello', as_h[0]['body']
  end

  def test_pom_returns_sections_after_prompt_add_section
    @agent.prompt_add_section('Topic', 'Body text')
    pom = @agent.pom

    refute_nil pom
    assert_kind_of SignalWire::POM::PromptObjectModel, pom
    as_h = pom.to_h

    assert_equal 1, as_h.length
    assert_equal 'Topic', as_h[0]['title']
    assert_equal 'Body text', as_h[0]['body']
  end

  def test_pom_nil_when_in_text_mode
    # set_prompt_text disables POM mode; pom must return nil to mirror
    # Python's "self.pom is None when use_pom is False".
    @agent.set_prompt_text('plain text')

    assert_nil @agent.pom
  end

  def test_pom_returns_fresh_instance_not_internal_state
    @agent.prompt_add_section('Original', 'Body')
    pom = @agent.pom

    refute_nil pom

    # Mutate the returned PromptObjectModel; internal state must be unchanged.
    pom.add_section('Injected', body: 'leaked')
    pom.sections[0].title = 'Hijacked'

    fresh = @agent.pom
    fresh_h = fresh.to_h

    assert_equal 1, fresh_h.length, 'caller mutation leaked into agent state'
    assert_equal 'Original', fresh_h[0]['title'], 'caller mutation leaked into agent state'
  end

  def test_pom_renders_markdown
    # Wire-through smoke test: agent.pom is a real PromptObjectModel
    # so caller can call render_markdown / render_xml / to_json on it
    # directly (matches Python's ``agent.pom.render_markdown()`` usage).
    @agent.prompt_add_section('Topic', 'Body text')
    md = @agent.pom.render_markdown

    assert_includes md, '## Topic'
    assert_includes md, 'Body text'
  end
end
