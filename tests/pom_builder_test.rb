# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class PomBuilderTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_build_complex_pom
    @agent.prompt_add_section('Identity', 'You are a helpful assistant')
    @agent.prompt_add_section('Rules', nil, bullets: ['Be concise', 'Be accurate', 'Be polite'])
    @agent.prompt_add_section('Knowledge', 'You know about SignalWire')
    @agent.prompt_add_subsection('Knowledge', 'Products', 'SW offers many products',
                                 bullets: %w[Voice Video Messaging])

    prompt = @agent.get_prompt

    assert_equal 3, prompt.length
    assert_identity_section(prompt[0])
    assert_rules_section(prompt[1])
    assert_knowledge_section(prompt[2])
  end

  def assert_identity_section(identity)
    assert_equal 'Identity', identity['title']
    assert_equal 'You are a helpful assistant', identity['body']
  end

  def assert_rules_section(rules)
    assert_equal 'Rules', rules['title']
    assert_equal 3, rules['bullets'].length
  end

  def assert_knowledge_section(knowledge)
    assert_equal 'Knowledge', knowledge['title']
    assert_equal 1, knowledge['subsections'].length
    sub = knowledge['subsections'][0]

    assert_equal 'Products', sub['title']
    assert_equal 3, sub['bullets'].length
  end

  def test_pom_renders_in_swml_correctly
    @agent.prompt_add_section('Task', 'Help users', bullets: ['Be friendly'])
    swml = @agent.render_swml
    prompt = swml['sections']['main'].find { |v| v.key?('ai') }['ai']['prompt']

    assert prompt.key?('pom')
    pom = prompt['pom']

    assert_equal 1, pom.length
    assert_equal 'Task', pom[0]['title']
  end

  def test_switching_modes_clears_previous
    @agent.set_prompt_text('Raw text')

    assert_equal 'Raw text', @agent.get_prompt

    assert_section_then_pom_modes

    @agent.set_prompt_text('Back to text')

    assert_equal 'Back to text', @agent.get_prompt
  end

  # Switching into section mode then explicit POM mode each yields an Array
  # prompt, and the POM mode reflects the directly-set section.
  def assert_section_then_pom_modes
    @agent.prompt_add_section('Section', 'Body')

    assert_instance_of Array, @agent.get_prompt

    @agent.set_prompt_pom([{ 'title' => 'Direct', 'body' => 'POM' }])
    prompt = @agent.get_prompt

    assert_instance_of Array, prompt
    assert_equal 'Direct', prompt[0]['title']
  end

  def test_add_to_nonexistent_section_creates_it
    # Python parity: prompt_add_to_section creates the section when
    # it's missing (matches PromptManager#prompt_add_to_section).
    @agent.prompt_add_section('A', 'Body A')
    @agent.prompt_add_to_section('B', ' extra')
    prompt = @agent.get_prompt

    assert_equal 2, prompt.length
    a_sec = prompt.find { |s| s['title'] == 'A' }
    b_sec = prompt.find { |s| s['title'] == 'B' }

    refute_nil a_sec
    refute_nil b_sec
    assert_equal 'Body A', a_sec['body']
    assert_equal ' extra', b_sec['body']
  end

  def test_subsection_to_nonexistent_parent
    @agent.prompt_add_section('A', 'Body A')
    @agent.prompt_add_subsection('B', 'Sub', 'Body')
    prompt = @agent.get_prompt

    assert_equal 1, prompt.length
    refute prompt[0].key?('subsections')
  end
end
