# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Regression tests for the behavior-parity bundle (#191/#185/#182/#183).
# Each fix is verified against the TypeScript reference behavior (and Python
# for #183's extraction order).

# Captures warn() calls so the #191 drop-warning can be asserted even when
# SIGNALWIRE_LOG_MODE=off would otherwise suppress output.
class CapturingLogger
  attr_reader :warnings

  def initialize
    @warnings = []
  end

  def warn(msg)
    @warnings << msg
  end

  def info(_msg); end
  def debug(_msg); end
  def error(_msg); end
end

# --- #191: set_function_includes drops invalid entries and warns per drop ---
class FunctionIncludesDropFilterTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
    @logger = CapturingLogger.new
    @agent.instance_variable_set(:@logger, @logger)
  end

  def ai_block
    @agent.render_swml['sections']['main'].find { |v| v.key?('ai') }['ai']
  end

  # A valid entry plus four invalid shapes (no url, no functions, non-array
  # functions, not a hash).
  def mixed_includes
    [
      { 'url' => 'https://good.com', 'functions' => %w[f1 f2] },
      { 'functions' => ['f3'] },
      { 'url' => 'https://nofuncs.com' },
      { 'url' => 'https://badfuncs.com', 'functions' => 'f4' },
      'not-a-hash'
    ]
  end

  def test_drops_entries_missing_url_or_functions
    @agent.set_function_includes(mixed_includes)
    includes = ai_block['SWAIG']['includes']

    assert_equal 1, includes.length
    assert_equal 'https://good.com', includes[0]['url']
  end

  def test_warns_once_per_dropped_entry
    @agent.set_function_includes(
      [
        { 'url' => 'https://good.com', 'functions' => ['f1'] },
        { 'functions' => ['f3'] },
        { 'url' => 'https://nofuncs.com' }
      ]
    )

    assert_equal 2, @logger.warnings.length
    assert(@logger.warnings.all? { |w| w.include?('invalid_function_include_dropped') })
  end

  def test_keeps_all_valid_entries
    @agent.set_function_includes(
      [
        { 'url' => 'https://a.com', 'functions' => ['f1'] },
        { 'url' => 'https://b.com', 'functions' => [] }
      ]
    )

    assert_equal 2, @agent.render_swml['sections']['main']
                          .find { |v| v.key?('ai') }['ai']['SWAIG']['includes'].length
    assert_empty @logger.warnings
  end
end

# --- #185: empty prompt falls back to the default assistant prompt ---
class DefaultPromptFallbackTest < Minitest::Test
  def ai_block(agent)
    agent.render_swml['sections']['main'].find { |v| v.key?('ai') }['ai']
  end

  def test_empty_prompt_emits_fallback_text
    agent = SignalWire::AgentBase.new(name: 'helper')
    prompt = ai_block(agent)['prompt']

    refute_nil prompt
    assert_equal 'You are helper, a helpful AI assistant.', prompt['text']
  end

  def test_explicit_prompt_is_not_overridden
    agent = SignalWire::AgentBase.new(name: 'helper')
    agent.set_prompt_text('Custom prompt')

    assert_equal 'Custom prompt', ai_block(agent)['prompt']['text']
  end
end

# --- #182: prompt_add_subsection auto-creates a missing parent section ---
class SubsectionAutoCreateTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_auto_creates_missing_parent
    @agent.prompt_add_subsection('Ghost', 'Sub', 'Sub body', bullets: %w[a b])
    parent = @agent.get_prompt.find { |s| s['title'] == 'Ghost' }

    refute_nil parent, 'parent section should be auto-created'
    assert_equal([{ 'title' => 'Sub', 'body' => 'Sub body', 'bullets' => %w[a b] }],
                 parent['subsections'])
  end

  def test_existing_parent_still_used
    @agent.prompt_add_section('Main', 'Top body')
    @agent.prompt_add_subsection('Main', 'Sub', 'Sub body')
    prompt = @agent.get_prompt

    assert_equal 1, prompt.length
    assert_equal 1, prompt[0]['subsections'].length
  end
end

# --- #183: on_summary extraction order (summary -> parsed[0] -> raw) ---
class SummaryExtractionOrderTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
    @received = nil
    @agent.on_summary { |summary, _raw| @received = summary }
  end

  def test_prefers_top_level_summary_key
    @agent.send(
      :invoke_summary_callback,
      {
        'summary' => { 'top' => 'level' },
        'post_prompt_data' => { 'parsed' => [{ 'p' => 1 }], 'raw' => '{"r":2}' }
      }
    )

    assert_equal({ 'top' => 'level' }, @received)
  end

  def test_falls_back_to_first_parsed_element
    @agent.send(
      :invoke_summary_callback,
      { 'post_prompt_data' => { 'parsed' => [{ 'first' => 1 }, { 'second' => 2 }], 'raw' => '{"r":2}' } }
    )

    assert_equal({ 'first' => 1 }, @received)
  end

  def test_falls_back_to_raw_json_parsed
    @agent.send(
      :invoke_summary_callback,
      { 'post_prompt_data' => { 'raw' => '{"r":2}' } }
    )

    assert_equal({ 'r' => 2 }, @received)
  end

  def test_raw_returned_as_string_when_not_json
    @agent.send(
      :invoke_summary_callback,
      { 'post_prompt_data' => { 'raw' => 'plain text summary' } }
    )

    assert_equal 'plain text summary', @received
  end

  def test_empty_parsed_array_falls_through_to_raw
    @agent.send(
      :invoke_summary_callback,
      { 'post_prompt_data' => { 'parsed' => [], 'raw' => 'fallback' } }
    )

    assert_equal 'fallback', @received
  end

  def test_nil_when_nothing_present
    @agent.send(:invoke_summary_callback, { 'post_prompt_data' => {} })

    assert_nil @received
  end
end
