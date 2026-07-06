# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/signalwire/swaig/function_result'
require_relative '../../lib/signalwire/prefabs/info_gatherer'

class InfoGathererPrefabDetailedTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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

  def test_handle_submit
    # submit_answer is a real state machine (not an echo): it records the
    # answer into global_data and advances the index. For a single-question
    # gatherer, submitting the only answer completes the flow.
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    result = agent.handle_submit({ 'answer' => 'Alice' }, {})

    action = result.to_h['action'].find { |a| a.key?('set_global_data') }['set_global_data']

    assert_equal [{ 'key_name' => 'name', 'answer' => 'Alice' }], action['answers']
    assert_equal 1, action['question_index']
    assert_match(/all questions have been answered/i, result.response)
  end

  def test_raises_without_questions
    assert_raises(ArgumentError) { SignalWire::Prefabs::InfoGatherer.new(questions: []) }
  end

  def test_prompt_sections
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    sections = agent.prompt_sections

    assert_equal 1, sections.size
    assert_equal 'Info Gatherer', sections[0]['title']
  end

  def test_global_data
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )
    data = agent.global_data

    assert data.key?('info_gatherer')
    assert_equal 0, data['info_gatherer']['question_index']
  end

  def test_custom_name_and_route
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }],
      name: 'custom', route: '/custom'
    )

    assert_equal 'custom', agent.name
    assert_equal '/custom', agent.route
  end

  # -------------------------------------------------------------------------
  # Behavioral contract #3: submit_answer STATE MACHINE (not an echo stub).
  #
  # With 2 questions at index 0, submitting an answer must (a) record the
  # answer in global_data.answers, (b) advance question_index to 1, and (c)
  # present the SECOND question. The old stub returned "Answer recorded: X"
  # with no state — it FAILS (a), (b) and (c). Mirrors Python
  # InfoGathererAgent.submit_answer.
  # -------------------------------------------------------------------------
  TWO_QUESTIONS = [
    { 'key_name' => 'name',  'question_text' => 'What is your name?' },
    { 'key_name' => 'email', 'question_text' => 'What is your email?' }
  ].freeze

  def two_question_agent
    SignalWire::Prefabs::InfoGatherer.new(questions: TWO_QUESTIONS.map(&:dup))
  end

  # The set_global_data payload the state machine writes into the result.
  def submitted_state(result)
    result.to_h['action'].find { |a| a.key?('set_global_data') }['set_global_data']
  end

  def test_submit_answer_advances_state_and_presents_next_question
    agent = two_question_agent
    # Simulate the SWAIG runtime handing back the seeded global_data (index 0).
    raw = { 'global_data' => { 'questions' => agent.questions, 'question_index' => 0, 'answers' => [] } }
    result = agent.handle_submit({ 'answer' => 'Alice' }, raw)
    state  = submitted_state(result)

    assert_equal [{ 'key_name' => 'name', 'answer' => 'Alice' }], state['answers'] # (a) recorded
    assert_equal 1, state['question_index'] # (b) advanced 0 -> 1
    assert_match(/What is your email\?/, result.response) # (c) 2nd question presented
    refute_match(/answer recorded:/i, result.response) # not the old echo stub
  end

  def test_submit_answer_completes_after_last_question
    agent = two_question_agent
    raw = { 'global_data' => { 'questions' => agent.questions, 'question_index' => 1,
                               'answers' => [{ 'key_name' => 'name', 'answer' => 'Alice' }] } }
    result = agent.handle_submit({ 'answer' => 'a@b.com' }, raw)
    state  = submitted_state(result)

    assert_equal 2, state['question_index']
    assert_equal 2, state['answers'].size
    assert_equal 'a@b.com', state['answers'].last['answer']
    assert_match(/all questions have been answered/i, result.response)
  end

  # start_questions must read the index from global_data and present that
  # question (real state, not always the first).
  def test_start_questions_presents_current_indexed_question
    agent = two_question_agent
    raw = { 'global_data' => { 'questions' => agent.questions, 'question_index' => 1, 'answers' => [] } }
    result = agent.handle_start({}, raw)

    assert_match(/What is your email\?/, result.response)
  end

  # The prefab is a REAL functional agent: it composes AgentBase and registers
  # its tools via define_tool, so the rendered SWML advertises them.
  def test_prefab_composes_agentbase_and_registers_tools
    agent = SignalWire::Prefabs::InfoGatherer.new(
      questions: [{ 'key_name' => 'name', 'question_text' => 'Name?' }]
    )

    assert_kind_of SignalWire::AgentBase, agent

    swml = agent.render_swml
    ai   = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    fn_names = ai['SWAIG']['functions'].map { |f| f['function'] }

    assert_includes fn_names, 'start_questions'
    assert_includes fn_names, 'submit_answer'
  end
end
