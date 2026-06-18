# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/contexts/context_builder'

CB  = SignalWire::Contexts::ContextBuilder
CTX = SignalWire::Contexts::Context
STP = SignalWire::Contexts::Step
GI  = SignalWire::Contexts::GatherInfo
GQ  = SignalWire::Contexts::GatherQuestion

class ContextsTest < Minitest::Test
  # ================================================================
  # ContextBuilder
  # ================================================================

  def test_builder_creation
    builder = CB.new

    assert_instance_of CB, builder
  end

  # --- Python parity: ContextBuilder(agent) ----------------------
  def test_builder_constructor_accepts_agent
    fake_agent = Object.new
    builder = CB.new(fake_agent)
    # Internally @agent is set; validate! passes a builder with no
    # contexts because @agent path isn't reached, so we use
    # introspection.
    assert_same fake_agent, builder.instance_variable_get(:@agent)
  end

  def test_builder_constructor_no_arg_default_nil_agent
    builder = CB.new

    assert_nil builder.instance_variable_get(:@agent)
  end

  # --- Python parity: Context#add_step(name, *, task:, bullets:, ...) ---
  def test_add_step_one_call_full_config
    builder = CB.new
    ctx = builder.add_context('default')
    step = ctx.add_step('greet', task: 'Greet the user', bullets: ['Say hello', 'Ask their name'],
                                 criteria: 'User has been greeted', functions: ['none'], valid_steps: ['greet'])

    h = step.to_h

    assert_includes h['text'], 'Greet the user'
    assert_includes h['text'], 'Say hello'
    assert_equal 'User has been greeted', h['step_criteria']
    assert_equal ['none'], h['functions']
    assert_equal ['greet'], h['valid_steps']
  end

  def test_add_step_returns_step_when_no_optional_args
    builder = CB.new
    ctx = builder.add_context('default')
    step = ctx.add_step('plain')

    assert_kind_of STP, step
    assert_equal 'plain', step.name
  end

  # --- Python parity: Step#add_gather_question explicit kwargs --
  def test_add_gather_question_with_explicit_args
    q = gather_question_with_explicit_args

    assert_equal 'email', q['key']
    assert_equal 'What is your email?', q['question']
    assert q['confirm']
    assert_equal 'Verify the email is well-formed.', q['prompt']
    assert_equal ['validate_email'], q['functions']
  end

  def gather_question_with_explicit_args
    step = CB.new.add_context('default').add_step('s1').set_text('hi')
    step.set_gather_info(output_key: 'data')
    step.add_gather_question(key: 'email', question: 'What is your email?', type: 'string', confirm: true,
                             prompt: 'Verify the email is well-formed.', functions: ['validate_email'])
    step.to_h['gather_info']['questions'].first
  end

  def test_builder_add_context
    builder = CB.new
    ctx = builder.add_context('default')

    assert_instance_of CTX, ctx
    assert_equal 'default', ctx.name
  end

  def test_builder_get_context
    builder = CB.new
    builder.add_context('default')

    assert_instance_of CTX, builder.get_context('default')
    assert_nil builder.get_context('nonexistent')
  end

  def test_builder_duplicate_context_raises
    builder = CB.new
    builder.add_context('default')
    assert_raises(ArgumentError) { builder.add_context('default') }
  end
end

# ContextBuilder validation
class ContextsBuilderValidateTest < Minitest::Test
  def test_builder_validate_empty_raises
    builder = CB.new
    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_builder_validate_single_context_must_be_default
    builder = CB.new
    ctx = builder.add_context('custom')
    ctx.add_step('step1').set_text('Hello')
    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_builder_validate_single_context_default_ok
    builder = CB.new
    ctx = builder.add_context('default')
    ctx.add_step('step1').set_text('Hello')

    assert builder.validate!
  end

  def test_builder_validate_context_needs_steps
    builder = CB.new
    builder.add_context('default')
    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_builder_validate_multiple_contexts_ok
    builder = CB.new
    c1 = builder.add_context('sales')
    c1.add_step('intro').set_text('Welcome to sales')
    c2 = builder.add_context('support')
    c2.add_step('intro').set_text('Welcome to support')

    assert builder.validate!
  end

  def test_builder_validate_invalid_step_reference
    builder = CB.new
    ctx = builder.add_context('default')
    ctx.add_step('step1').set_text('Hello').set_valid_steps(%w[nonexistent])
    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_builder_validate_valid_step_reference_next
    builder = CB.new
    ctx = builder.add_context('default')
    ctx.add_step('step1').set_text('Hello').set_valid_steps(%w[next])

    assert builder.validate!
  end

  def test_builder_validate_invalid_context_reference_at_context_level
    builder = CB.new
    c1 = builder.add_context('default')
    c1.add_step('step1').set_text('Hello')
    c1.set_valid_contexts(%w[nonexistent])
    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_builder_validate_invalid_context_reference_at_step_level
    builder = CB.new
    ctx = builder.add_context('default')
    ctx.add_step('step1').set_text('Hello').set_valid_contexts(%w[ghost])
    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_builder_to_h_serialization
    builder = CB.new
    ctx = builder.add_context('default')
    ctx.add_step('greet').set_text('Say hello')
    ctx.add_step('farewell').set_text('Say goodbye')

    h = builder.to_h

    assert h.key?('default')
    names = h['default']['steps'].map { |s| s['name'] }

    assert_equal %w[greet farewell], names
  end
end

# ================================================================
# Context
# ================================================================
class ContextsContextTest < Minitest::Test
  def test_context_add_step_returns_step
    ctx = CTX.new('default')
    step = ctx.add_step('greeting')

    assert_instance_of STP, step
    assert_equal 'greeting', step.name
  end

  def test_context_duplicate_step_raises
    ctx = CTX.new('default')
    ctx.add_step('step1')
    assert_raises(ArgumentError) { ctx.add_step('step1') }
  end

  def test_context_get_step
    ctx = CTX.new('default')
    ctx.add_step('step1')

    assert_instance_of STP, ctx.get_step('step1')
    assert_nil ctx.get_step('missing')
  end

  def test_context_remove_step
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('A')
    ctx.add_step('s2').set_text('B')
    ctx.remove_step('s1')

    assert_nil ctx.get_step('s1')

    h = ctx.to_h

    assert_equal 1, h['steps'].size
    assert_equal 's2', h['steps'][0]['name']
  end

  def test_context_remove_nonexistent_step
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('A')
    # Should not raise
    ctx.remove_step('nope')

    assert_equal 1, ctx._steps.size
  end

  def test_context_move_step
    ctx = CTX.new('default')
    ctx.add_step('a').set_text('A')
    ctx.add_step('b').set_text('B')
    ctx.add_step('c').set_text('C')
    ctx.move_step('c', 0)

    h = ctx.to_h

    assert_equal(%w[c a b], h['steps'].map { |s| s['name'] })
  end

  def test_context_move_step_not_found_raises
    ctx = CTX.new('default')
    ctx.add_step('a').set_text('A')
    assert_raises(ArgumentError) { ctx.move_step('missing', 0) }
  end

  def test_context_valid_contexts
    ctx = CTX.new('main')
    ctx.add_step('s1').set_text('x')
    ctx.set_valid_contexts(%w[sales support])

    h = ctx.to_h

    assert_equal %w[sales support], h['valid_contexts']
  end

  def test_context_valid_steps
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_valid_steps(%w[next s1])

    h = ctx.to_h

    assert_equal %w[next s1], h['valid_steps']
  end
end

# Context (continued): prompts, sections, fillers, chaining
class ContextsContextPromptTest < Minitest::Test
  def test_context_post_prompt
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_post_prompt('Evaluate the conversation')

    h = ctx.to_h

    assert_equal 'Evaluate the conversation', h['post_prompt']
  end

  def test_context_system_prompt
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_system_prompt('You are a helpful agent')

    h = ctx.to_h

    assert_equal 'You are a helpful agent', h['system_prompt']
  end

  def test_context_set_prompt
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_prompt('Context prompt text')

    h = ctx.to_h

    assert_equal 'Context prompt text', h['prompt']
  end

  def test_context_consolidate_and_full_reset
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_consolidate(true).set_full_reset(true)

    h = ctx.to_h

    assert h['consolidate']
    assert h['full_reset']
  end

  def test_context_user_prompt
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_user_prompt('Hello there')

    h = ctx.to_h

    assert_equal 'Hello there', h['user_prompt']
  end

  def test_context_isolated
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_isolated(true)

    h = ctx.to_h

    assert h['isolated']
  end

  def test_context_add_section_and_bullets
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.add_section('Overview', 'This is the overview')
    ctx.add_bullets('Rules', %w[rule1 rule2])
    pom = ctx.to_h['pom']

    assert_equal 2, pom.size
    assert_equal({ 'title' => 'Overview', 'body' => 'This is the overview' },
                 pom[0].slice('title', 'body'))
    assert_equal %w[rule1 rule2], pom[1]['bullets']
  end

  def test_context_set_prompt_and_add_section_conflict
    ctx = CTX.new('default')
    ctx.set_prompt('text')
    assert_raises(ArgumentError) { ctx.add_section('Title', 'Body') }
  end

  def test_context_add_section_and_set_prompt_conflict
    ctx = CTX.new('default')
    ctx.add_section('Title', 'Body')
    assert_raises(ArgumentError) { ctx.set_prompt('text') }
  end

  def test_context_system_prompt_sections
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.add_system_section('Identity', 'You are a bot')
    ctx.add_system_bullets('Guidelines', %w[be_nice be_helpful])

    h = ctx.to_h

    assert_includes h['system_prompt'], '## Identity'
    assert_includes h['system_prompt'], 'You are a bot'
    assert_includes h['system_prompt'], '- be_nice'
  end

  def test_context_system_prompt_and_sections_conflict
    ctx = CTX.new('default')
    ctx.set_system_prompt('text')
    assert_raises(ArgumentError) { ctx.add_system_section('T', 'B') }
  end

  def test_context_system_sections_and_prompt_conflict
    ctx = CTX.new('default')
    ctx.add_system_section('T', 'B')
    assert_raises(ArgumentError) { ctx.set_system_prompt('text') }
  end
end

# Context (continued): fillers and chaining
class ContextsContextFillerTest < Minitest::Test
  def test_context_enter_fillers
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_enter_fillers({ 'en-US' => ['Welcome!'], 'default' => ['Hi'] })

    h = ctx.to_h

    assert_equal ['Welcome!'], h['enter_fillers']['en-US']
    assert_equal ['Hi'], h['enter_fillers']['default']
  end

  def test_context_exit_fillers
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.set_exit_fillers({ 'en-US' => ['Goodbye!'] })

    h = ctx.to_h

    assert_equal ['Goodbye!'], h['exit_fillers']['en-US']
  end

  def test_context_add_enter_filler
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.add_enter_filler('en-US', ['Welcome!'])
    ctx.add_enter_filler('es', ['Bienvenido!'])

    h = ctx.to_h

    assert_equal ['Welcome!'], h['enter_fillers']['en-US']
    assert_equal ['Bienvenido!'], h['enter_fillers']['es']
  end

  def test_context_add_exit_filler
    ctx = CTX.new('default')
    ctx.add_step('s1').set_text('x')
    ctx.add_exit_filler('en-US', ['Bye!'])

    h = ctx.to_h

    assert_equal ['Bye!'], h['exit_fillers']['en-US']
  end

  def test_context_no_steps_raises_on_to_h
    ctx = CTX.new('empty')
    assert_raises(ArgumentError) { ctx.to_h }
  end

  def test_context_chaining_returns_self
    ctx = CTX.new('default')
    chained = ctx
              .set_valid_contexts(%w[a]).set_valid_steps(%w[b]).set_post_prompt('pp')
              .set_consolidate(true).set_full_reset(true).set_user_prompt('up')
              .set_isolated(true).set_enter_fillers({ 'x' => ['y'] }).set_exit_fillers({ 'x' => ['y'] })
              .add_enter_filler('en', ['hi']).add_exit_filler('en', ['bye']).remove_step('nonexistent')

    assert_same ctx, chained
  end
end

# ================================================================
# Step
# ================================================================
class ContextsStepTest < Minitest::Test
  def test_step_set_text
    step = STP.new('intro')
    step.set_text('Welcome to the system')

    h = step.to_h

    assert_equal 'intro', h['name']
    assert_equal 'Welcome to the system', h['text']
  end

  def test_step_add_section
    step = STP.new('intro')
    step.add_section('Task', 'Greet the user')

    h = step.to_h

    assert_includes h['text'], '## Task'
    assert_includes h['text'], 'Greet the user'
  end

  def test_step_add_bullets
    step = STP.new('process')
    step.add_bullets('Rules', %w[be_nice be_helpful])

    h = step.to_h

    assert_includes h['text'], '## Rules'
    assert_includes h['text'], '- be_nice'
    assert_includes h['text'], '- be_helpful'
  end

  def test_step_mixed_sections_and_bullets
    step = STP.new('complex')
    step.add_section('Task', 'Do the thing')
    step.add_bullets('Steps', %w[step1 step2])

    h = step.to_h

    assert_includes h['text'], '## Task'
    assert_includes h['text'], 'Do the thing'
    assert_includes h['text'], '## Steps'
    assert_includes h['text'], '- step1'
  end

  def test_step_text_and_sections_conflict
    step = STP.new('intro')
    step.set_text('Direct text')
    assert_raises(ArgumentError) { step.add_section('T', 'B') }
  end

  def test_step_sections_and_text_conflict
    step = STP.new('intro')
    step.add_section('T', 'B')
    assert_raises(ArgumentError) { step.set_text('Direct text') }
  end

  def test_step_bullets_and_text_conflict
    step = STP.new('intro')
    step.set_text('Direct text')
    assert_raises(ArgumentError) { step.add_bullets('T', %w[a]) }
  end

  def test_step_no_text_or_sections_raises
    step = STP.new('empty')
    assert_raises(ArgumentError) { step.to_h }
  end

  def test_step_criteria
    step = STP.new('s1').set_text('x').set_step_criteria('User has provided name')

    h = step.to_h

    assert_equal 'User has provided name', h['step_criteria']
  end

  def test_step_functions_none
    step = STP.new('s1').set_text('x').set_functions('none')

    h = step.to_h

    assert_equal 'none', h['functions']
  end

  def test_step_functions_list
    step = STP.new('s1').set_text('x').set_functions(%w[search lookup])

    h = step.to_h

    assert_equal %w[search lookup], h['functions']
  end

  def test_step_valid_steps
    step = STP.new('s1').set_text('x').set_valid_steps(%w[next s2])

    h = step.to_h

    assert_equal %w[next s2], h['valid_steps']
  end

  def test_step_valid_contexts
    step = STP.new('s1').set_text('x').set_valid_contexts(%w[sales support])

    h = step.to_h

    assert_equal %w[sales support], h['valid_contexts']
  end
end

# Step (continued): flags, reset, chaining
class ContextsStepFlagsTest < Minitest::Test
  def test_step_end
    step = STP.new('final').set_text('Goodbye').set_end(true)

    h = step.to_h

    assert h['end']
  end

  def test_step_skip_user_turn
    step = STP.new('auto').set_text('Processing').set_skip_user_turn(true)

    h = step.to_h

    assert h['skip_user_turn']
  end

  def test_step_skip_to_next_step
    step = STP.new('transit').set_text('Moving on').set_skip_to_next_step(true)

    h = step.to_h

    assert h['skip_to_next_step']
  end

  def test_step_reset_object
    reset = step_with_reset.to_h['reset']

    refute_nil reset
    assert_equal 'New system prompt', reset['system_prompt']
    assert_equal 'New user prompt', reset['user_prompt']
    assert reset['consolidate']
    assert reset['full_reset']
  end

  def step_with_reset
    STP.new('switch').set_text('Switching context')
       .set_reset_system_prompt('New system prompt').set_reset_user_prompt('New user prompt')
       .set_reset_consolidate(true).set_reset_full_reset(true)
  end

  def test_step_no_reset_when_not_set
    step = STP.new('normal').set_text('Normal step')

    h = step.to_h

    refute h.key?('reset')
  end

  def test_step_clear_sections
    step = STP.new('s1')
    step.add_section('T', 'B')
    step.clear_sections
    # After clearing we can use set_text
    step.set_text('New text')

    h = step.to_h

    assert_equal 'New text', h['text']
  end

  def test_step_chaining_returns_self
    assert_same(s1 = STP.new('s1'), s1.set_text('x'))
    assert_same(s2 = STP.new('s2'), s2.add_section('T', 'B'))

    step3 = STP.new('s3')
    step3.add_section('T', 'B')

    assert_same step3, chain_all_setters(step3)
  end

  def chain_all_setters(step)
    step
      .set_step_criteria('c').set_functions('none').set_valid_steps(%w[a]).set_valid_contexts(%w[b])
      .set_end(true).set_skip_user_turn(true).set_skip_to_next_step(true)
      .set_reset_system_prompt('sp').set_reset_user_prompt('up')
      .set_reset_consolidate(true).set_reset_full_reset(true).clear_sections
  end
end

# ================================================================
# GatherInfo / GatherQuestion
# ================================================================
class ContextsGatherInfoTest < Minitest::Test
  def test_gather_question_to_h
    q = GQ.new(key: 'name', question: 'What is your name?')
    h = q.to_h

    assert_equal 'name', h['key']
    assert_equal 'What is your name?', h['question']
    refute h.key?('type') # default string is omitted
    refute h.key?('confirm')
  end

  def test_gather_question_with_options
    q = GQ.new(key: 'age', question: 'How old are you?', type: 'number',
               confirm: true, prompt: 'Please provide your age', functions: %w[lookup])
    h = q.to_h

    assert_equal 'number', h['type']
    assert h['confirm']
    assert_equal 'Please provide your age', h['prompt']
    assert_equal %w[lookup], h['functions']
  end

  def test_gather_info_basic
    gi = GI.new(output_key: 'user_info', completion_action: 'next_step', prompt: 'Please answer:')
    gi.add_question(key: 'name', question: 'Your name?')
    gi.add_question(key: 'email', question: 'Your email?')

    h = gi.to_h

    assert_equal 2, h['questions'].size
    assert_equal 'user_info', h['output_key']
    assert_equal 'next_step', h['completion_action']
    assert_equal 'Please answer:', h['prompt']
  end

  def test_gather_info_empty_questions_raises
    gi = GI.new
    assert_raises(ArgumentError) { gi.to_h }
  end

  def test_gather_info_chaining
    gi = GI.new
    result = gi.add_question(key: 'q1', question: 'Q1?')

    assert_same gi, result
  end

  def test_step_gather_info
    gi = step_with_gather_info.to_h['gather_info']

    refute_nil gi
    assert_equal 2, gi['questions'].size
    assert_equal 'data', gi['output_key']
    assert_equal 'We need some info', gi['prompt']
    assert_equal 'number', gi['questions'][1]['type']
  end

  def step_with_gather_info
    STP.new('gather').set_text('Gathering info')
       .set_gather_info(output_key: 'data', prompt: 'We need some info')
       .add_gather_question(key: 'name', question: 'Your name?')
       .add_gather_question(key: 'age', question: 'Your age?', type: 'number', confirm: true)
  end

  def test_step_gather_question_without_gather_info_raises
    step = STP.new('s1').set_text('x')
    assert_raises(ArgumentError) { step.add_gather_question(key: 'k', question: 'q') }
  end

  def test_step_set_gather_info_returns_self
    step = STP.new('s1').set_text('x')
    result = step.set_gather_info

    assert_same step, result
  end
end

# ================================================================
# Validation: gather_info
# ================================================================
class ContextsGatherValidationTest < Minitest::Test
  def test_validate_gather_info_no_questions
    builder = CB.new
    ctx = builder.add_context('default')
    ctx.add_step('s1').set_text('x').set_gather_info

    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_validate_gather_info_duplicate_keys
    builder = CB.new
    ctx = builder.add_context('default')
    step = ctx.add_step('s1').set_text('x')
    step.set_gather_info
    step.add_gather_question(key: 'name', question: 'Name?')
    step.add_gather_question(key: 'name', question: 'Name again?')

    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_validate_gather_info_completion_action_next_step_last_raises
    builder = CB.new
    ctx = builder.add_context('default')
    step = ctx.add_step('s1').set_text('x')
    step.set_gather_info(completion_action: 'next_step')
    step.add_gather_question(key: 'q', question: 'Q?')

    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_validate_gather_info_completion_action_next_step_ok
    builder = CB.new
    ctx = builder.add_context('default')
    step = ctx.add_step('s1').set_text('x')
    step.set_gather_info(completion_action: 'next_step')
    step.add_gather_question(key: 'q', question: 'Q?')
    ctx.add_step('s2').set_text('Done')

    assert builder.validate!
  end

  def test_validate_gather_info_completion_action_invalid_step
    builder = CB.new
    ctx = builder.add_context('default')
    step = ctx.add_step('s1').set_text('x')
    step.set_gather_info(completion_action: 'nonexistent')
    step.add_gather_question(key: 'q', question: 'Q?')

    assert_raises(ArgumentError) { builder.validate! }
  end

  def test_validate_gather_info_completion_action_valid_step
    builder = CB.new
    ctx = builder.add_context('default')
    step = ctx.add_step('s1').set_text('x')
    step.set_gather_info(completion_action: 's2')
    step.add_gather_question(key: 'q', question: 'Q?')
    ctx.add_step('s2').set_text('Target')

    assert builder.validate!
  end

  # ================================================================
  # create_simple_context helper
  # ================================================================

  def test_create_simple_context_default_name
    ctx = SignalWire::Contexts.create_simple_context

    assert_instance_of CTX, ctx
    assert_equal 'default', ctx.name
  end

  def test_create_simple_context_custom_name
    ctx = SignalWire::Contexts.create_simple_context('custom')

    assert_equal 'custom', ctx.name
  end
end

# ================================================================
# Full integration: complex multi-context builder
# ================================================================
class ContextsIntegrationTest < Minitest::Test
  def test_full_integration
    h = build_integration_builder.to_h

    assert_equal %w[sales support], h.keys
    assert_integration_sales(h['sales'])
    assert_integration_support(h['support'])
  end

  def assert_integration_sales(sales)
    steps = sales['steps']

    assert_equal 3, steps.size
    assert steps[2]['end']
    assert_equal %w[support], sales['valid_contexts']
    assert sales['enter_fillers'].key?('en-US')
  end

  def assert_integration_support(support)
    steps = support['steps']

    assert_equal 1, steps.size
    assert_equal %w[lookup_ticket], steps[0]['functions']
  end

  private

  def build_integration_builder
    builder = CB.new
    build_sales_context(builder.add_context('sales'))
    support = builder.add_context('support')
    support.set_valid_contexts(%w[sales])
    support.add_step('triage').set_text('What issue are you experiencing?').set_functions(%w[lookup_ticket])
    builder
  end

  def build_sales_context(sales)
    sales.set_valid_contexts(%w[support])
    sales.set_enter_fillers({ 'en-US' => ['Welcome to sales!'] })
    sales.set_exit_fillers({ 'en-US' => ['Thanks for visiting sales!'] })
    sales.add_step('greeting').set_text('Hello! How can I help you with our products?')
         .set_step_criteria('User has expressed interest').set_valid_steps(%w[next]).set_functions(%w[search_products])
    qualify = sales.add_step('qualify')
    qualify.add_section('Task', 'Qualify the lead')
    qualify.add_bullets('Process', ['Ask budget', 'Ask timeline', 'Ask requirements'])
    qualify.set_step_criteria('All qualification info gathered').set_valid_steps(%w[next])
    sales.add_step('close').set_text('Great! Let me prepare a quote for you.').set_end(true)
  end
end

# --- Idiomatic Ruby accessor aliases (RUBY_ERGONOMICS_MIGRATION.md) ---
class ContextsIdiomaticAccessorsTest < Minitest::Test
  def setup
    @builder = SignalWire::Contexts::ContextBuilder.new
    @ctx     = @builder.add_context('default')
    @step    = @ctx.add_step('s1')
    @step.text = 'base' # to_h requires a step to have text/POM
  end

  # Step: X= writer mirrors set_X, and the chainable set_X still works.
  def test_step_writer_matches_setter
    @step.text = 'you are helpful'

    assert_equal 'you are helpful', @step.to_h['text']
    # chainable original still returns self
    assert_same @step, @step.set_text('again')
  end

  def test_step_valid_steps_writer
    @step.valid_steps = %w[next done]

    assert_equal %w[next done], @step.to_h['valid_steps']
  end

  # writer returns the RHS (Ruby = semantics), not self
  def test_writer_returns_rhs
    assert_equal 'x', (@step.text = 'x')
  end

  # Context: X= writer mirrors set_X (duplicate method name across Step/Context
  # — each aliased inside its own class).
  def test_context_writer_matches_setter
    @ctx.system_prompt = 'be terse'

    assert_equal 'be terse', @ctx.to_h['system_prompt']
  end
end
